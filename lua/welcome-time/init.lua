-- lua/welcome-time/init.lua

local M = {}
M.win_id = nil -- Сохраняем ID окна для управления им
M.buf_id = nil -- Сохраняем ID буфера
M.timer_id = nil -- Сохраняем ID таймера
M.time_line_nr = nil -- Сохраняем номер строки с временем

local default_config = {
  art = { "" },
  quotes = {
    "The computer was created to solve problems that did not exist before.",
    "Simplicity is the soul of effectiveness.",
  },
  username = vim.fn.expand "$USER",
  greetings = {
    morning = "Good morning, %s! ☀️", -- 6:00 - 11:59
    afternoon = "Good afternoon, %s! 🌞", -- 12:00 - 17:59
    evening = "Good evening, %s! 🌆", -- 18:00 - 21:59
    night = "Good night, %s! 🌙"
  },
  show_time = true,
  show_date = true,
  auto_close_time = 5000,
  close_on_file_open = true,
  highlight_group = "Title",
}

local config = {}

-- Функция для определения времени дня
local function get_time_period()
  local hour = tonumber(os.date "%H")

  if hour >= 6 and hour < 12 then
    return "morning"
  elseif hour >= 12 and hour < 18 then
    return "afternoon"
  elseif hour >= 18 and hour < 22 then
    return "evening"
  else
    return "night"
  end
end

-- Функция для получения приветствия
local function get_greeting()
  local period = get_time_period()
  local greeting_template = config.greetings[period]
  return string.format(greeting_template, config.username)
end

local function update_time_display()
  -- Убедимся, что все еще существует, прежде чем обновлять
  if not (M.buf_id and vim.api.nvim_buf_is_valid(M.buf_id) and M.time_line_nr) then
    return
  end

  -- Временно делаем буфер изменяемым
  vim.api.nvim_buf_set_option(M.buf_id, "modifiable", true)

  local new_time_line = "Time: " .. os.date "%H:%M:%S"
  local win_width = vim.api.nvim_win_get_width(M.win_id)
  local padding = math.floor((win_width - vim.fn.strwidth(new_time_line)) / 2)
  local centered_line = string.rep(" ", padding) .. new_time_line

  vim.api.nvim_buf_set_lines(M.buf_id, M.time_line_nr - 1, M.time_line_nr, false, { centered_line })

  -- Возвращаем обратно
  vim.api.nvim_buf_set_option(M.buf_id, "modifiable", false)
end

function M.close()
  -- Останавливаем таймер, если он есть
  if M.timer_id then
    vim.fn.timer_stop(M.timer_id)
    M.timer_id = nil
  end

  -- Закрываем окно, если оно есть
  if M.win_id and vim.api.nvim_win_is_valid(M.win_id) then
    vim.api.nvim_win_close(M.win_id, true)
  end

  -- Сбрасываем состояние
  M.win_id = nil
  M.buf_id = nil
  M.time_line_nr = nil
end

-- Функция для отображения приветствия
local function show_welcome()
  local lines = {}

  -- Добавляем ASCII-арт
  if config.art and #config.art > 0 then
    for _, art_line in ipairs(config.art) do
      table.insert(lines, art_line)
    end
    table.insert(lines, "")
  end

  -- Добавляем приветствие
  table.insert(lines, get_greeting())

  -- Добавляем пустую строку
  table.insert(lines, "")

  -- Добавляем случайную цитату
  if config.quotes and #config.quotes > 0 then
    math.randomseed(os.time())
    local random_quote = config.quotes[math.random(#config.quotes)]
    table.insert(lines, '"' .. random_quote .. '"')
  end

  table.insert(lines, "")

  -- Добавляем время, если включено
  if config.show_time then
    table.insert(lines, "Time: " .. os.date "%H:%M:%S")
    M.time_line_nr = #lines -- Запоминаем номер строки
  end

  -- Добавляем дату, если включено
  if config.show_date then
    table.insert(lines, "Date: " .. os.date "%Y-%m-%d")
  end

  -- Создаем буфер для приветствия
  local buf = vim.api.nvim_create_buf(false, true)
  M.buf_id = buf -- Сохраняем ID буфераcd
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  -- Вычисляем размеры окна
  local width = vim.api.nvim_get_option "columns"
  local height = vim.api.nvim_get_option "lines"

  local win_width = math.min(60, width - 4)
  local win_height = #lines + 2
  local row = math.ceil((height - win_height) / 2)
  local col = math.ceil((width - win_width) / 2)

  -- Создаем плавающее окно
  local win_opts = {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Welcome! ",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, false, win_opts)
  M.win_id = win -- Сохраняем ID окна

  -- Устанавливаем подсветку
  vim.api.nvim_win_set_option(win, "winhighlight", "Normal:" .. config.highlight_group)

  -- Центрируем текст
  for i, line in ipairs(lines) do
    if line ~= "" then
      local padding = math.floor((win_width - vim.fn.strwidth(line)) / 2)
      local centered_line = string.rep(" ", padding) .. line
      vim.api.nvim_buf_set_lines(buf, i - 1, i, false, { centered_line })
    end
  end

  -- Делаем буфер немодифицируемым ПОСЛЕ всех изменений
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  -- Автоматически закрываем окно, если настроено.
  -- Этот таймер не сработает, если включена опция close_on_file_open.
  if config.auto_close_time > 0 and not config.close_on_file_open then
    vim.defer_fn(function()
      M.close()
    end, config.auto_close_time)
  end

  -- Запускаем таймер для обновления времени, если опция включена
  if config.show_time then
    M.timer_id = vim.fn.timer_start(1000, function()
      vim.schedule(update_time_display)
    end, { ["repeat"] = -1 })
  end

  -- Добавляем возможность закрыть окно нажатием любой клавиши
  vim.api.nvim_buf_set_keymap(
    buf,
    "n",
    "<ESC>",
    '<cmd>lua require("welcome-time").close()<cr>',
    { noremap = true, silent = true }
  )
  vim.api.nvim_buf_set_keymap(
    buf,
    "n",
    "q",
    '<cmd>lua require("welcome-time").close()<cr>',
    { noremap = true, silent = true }
  )
  vim.api.nvim_buf_set_keymap(
    buf,
    "n",
    "<CR>",
    '<cmd>lua require("welcome-time").close()<cr>',
    { noremap = true, silent = true }
  )
end

-- Функция настройки плагина
function M.setup(user_config)
  -- Объединяем пользовательскую конфигурацию с конфигурацией по умолчанию
  config = vim.tbl_deep_extend("force", default_config, user_config or {})

  -- Создаем группу автокоманд, чтобы избежать дублирования
  local augroup = vim.api.nvim_create_augroup("WelcomeTime", { clear = true })

  -- Создаем автокоманду для показа приветствия при запуске
  vim.api.nvim_create_autocmd("VimEnter", {
    group = augroup,
    callback = function()
      -- Показываем приветствие только если не открыты файлы
      if vim.fn.argc() == 0 and vim.bo.filetype == "" then
        vim.defer_fn(show_welcome, 100) -- Небольшая задержка для корректного отображения
      end
    end,
    desc = "Show welcome message on startup",
  })

  -- Создаем автокоманду для закрытия окна при открытии файла
  if config.close_on_file_open then
    vim.api.nvim_create_autocmd("BufEnter", {
      group = augroup,
      callback = function()
        -- Проверяем, что окно приветствия еще существует
        if M.win_id and vim.api.nvim_win_is_valid(M.win_id) then
          local bufnr = vim.api.nvim_get_current_buf()
          -- Закрываем, если это обычный буфер с файлом (а не, например, дерево файлов)
          if vim.fn.buflisted(bufnr) == 1 and vim.bo[bufnr].buftype == "" then
            M.close()
          end
        end
      end,
      desc = "Close welcome message on file open",
    })
  end
end

-- Команда для ручного показа приветствия
vim.api.nvim_create_user_command("WelcomeShow", show_welcome, {
  desc = "Show welcome message",
})

return M
