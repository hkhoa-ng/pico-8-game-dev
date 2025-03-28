pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- Game engine
screen = "menu"
state = "dropping"
wavy_text_timer = 0
difficulties = {"classic", "normal", "easy"} 
diff = 3
diff_col = 0    -- color for difficulty
modes = 2   -- 1 for play, 2 for tutorial
tut_timer = 0   
tut_wait = 120   -- wait time between tutorial state
pause_tut_timer = false     -- pause time between dialog
tut_move_counter = 5    -- can move the new disc 5 times in stage 2

-- Tutorial
tut_stage = 0

-- Dialog system by rustybailey https://www.lexaloffle.com/bbs/?tid=39705
dialog = {
  x = 8,
  y = 97,
  color = 7,
  max_chars_per_line = 27,
  max_lines = 4,
  dialog_queue = {},
  blinking_counter = 0,
  callback = nil,  -- Add callback field
  init = function(self)
  end,
  queue = function(self, message, callback)
    add(self.dialog_queue, {
      message = message,
    })

    -- Store the callback if provided
    if callback then
      self.callback = callback
    end

    if (#self.dialog_queue == 1) then
      self:trigger(self.dialog_queue[1].message)
    end
  end,
  trigger = function(self, message)
    self.current_message = ''
    self.messages_by_line = nil
    self.animation_loop = nil
    self.current_line_in_table = 1
    self.current_line_count = 1
    self.pause_dialog = false
    self:format_message(message)
    self.animation_loop = cocreate(self.animate_text)
  end,
  format_message = function(self, message)
    local total_msg = {}
    local word = ''
    local letter = ''
    local current_line_msg = ''

    for i = 1, #message do
      letter = sub(message, i, i)
      word ..= letter

      if letter == ' ' or i == #message then
        local line_length = #current_line_msg + #word
        if line_length > self.max_chars_per_line then
          add(total_msg, current_line_msg)
          current_line_msg = word
        else
          current_line_msg ..= word
        end

        if i == #message then
          add(total_msg, current_line_msg)
        end

        word = ''
      end
    end

    self.messages_by_line = total_msg
  end,
  animate_text = function(self)
    for k, line in pairs(self.messages_by_line) do
      self.current_line_in_table = k
      for i = 1, #line do
        self.current_message ..= sub(line, i, i)
        if (not btnp(5)) then
          if (i % 5 == 0) sfx(0)
          yield()
        end
      end
      self.current_message ..= '\n'
      self.current_line_count += 1
      if ((self.current_line_count > self.max_lines) or (self.current_line_in_table == #self.messages_by_line)) then
        self.pause_dialog = true
        yield()
      end
    end
  end,
  shift = function(self, t)
    local n = #t
    for i = 1, n do
      if i < n then
        t[i] = t[i + 1]
      else
        t[i] = nil
      end
    end
  end,
  delay = function(frames)
    for i = 1, frames do
      yield()
    end
  end,
  update = function(self)
    if (self.animation_loop and costatus(self.animation_loop) != 'dead') then
      if (not self.pause_dialog) then
        coresume(self.animation_loop, self)
      else
        if btnp(4) then
          -- Check if we're at the end of the current message
          if self.current_line_in_table == #self.messages_by_line then
            -- Clear the current message and dialog state
            self.current_message = nil
            self.messages_by_line = nil
            self.animation_loop = nil
            self.current_line_in_table = 1
            self.current_line_count = 1
            self.pause_dialog = false
            -- Remove the current message from the queue
            self:shift(self.dialog_queue)
            -- Check if there's another message to display
            if #self.dialog_queue > 0 then
              self:trigger(self.dialog_queue[1].message)
            end
          else
            -- Not at the end of the message, just advance to the next part
            self.pause_dialog = false
            self.current_line_count = 1
            self.current_message = ''
          end
        end
      end
    elseif (self.animation_loop and self.current_message) then
      self.animation_loop = nil
    end

    -- Check if the dialog is completely finished
    if (not self.animation_loop and #self.dialog_queue == 0 and not self.current_message) then
      if self.callback then
        self.callback()  -- Run the callback
        self.callback = nil  -- Clear the callback to prevent repeated calls
      end
    end

    self.blinking_counter = (self.blinking_counter + 1) % 31
  end,
  draw = function(self)
    local screen_width = 128

    -- display message
    if (self.current_message) then
      if (#self.current_message > 0) then 
        rectfill(0, 90, 127, 127, 0)
        rect(0, 90, 127, 127, 7)
      end
      print(self.current_message, self.x, self.y, self.color)
    end

    -- draw blinking cursor at the bottom right
    if (self.pause_dialog) then
      if self.blinking_counter > 15 then
        if (self.current_line_in_table == #self.messages_by_line) then
          -- draw square
          rectfill(
            screen_width - 11,
            screen_width - 10,
            screen_width - 11 + 3,
            screen_width - 10 + 3,
            7
          )
        else
          -- draw arrow
          line(screen_width - 12, screen_width - 9, screen_width - 8, screen_width - 9, 7)
          line(screen_width - 11, screen_width - 8, screen_width - 9, screen_width - 8, 7)
          line(screen_width - 10, screen_width - 7, screen_width - 10, screen_width - 7, 7)
        end
      end
    end
  end
}

-- Screen transition
transition_active = false
fade_counter = 0
prev_screen = "menu"
next_screen = "menu"
fade_table={
    {0,0,0,0,0,0,0,0,0},
    {1,129,129,129,129,129,0,0,0},
    {2,2,130,130,130,128,128,128,0},
    {3,3,131,131,129,129,129,0,0},
    {4,132,132,132,132,128,128,128,0},
    {5,133,133,133,130,128,128,128,0},
    {6,134,13,13,5,5,133,128,128},
    {7,6,6,134,134,5,133,130,128},
    {8,136,136,136,132,132,128,128,0},
    {9,9,4,4,132,132,128,128,128},
    {10,138,138,4,4,132,133,128,128},
    {11,139,139,3,3,131,129,0,0},
    {12,140,140,140,131,131,1,129,0},
    {13,141,141,5,133,133,129,128,0},
    {14,134,134,141,2,132,130,128,128},
    {15,143,134,134,5,5,133,128,128}
}

-- Constants
grid = {
    {1,3,0,0,0,0,0},
    {1,3,0,0,0,0,0},
    {1,3,0,0,0,0,0},
    {1,3,0,5,0,0,0},
    {1,3,0,4,0,0,0},
    {1,3,0,2,0,0,0},
    {1,3,0,-2,0,0,0},
}
grid_size = 7
tile_size = 12
line_length = tile_size * (grid_size + 1)
grid_offset = 64 - line_length/2 - tile_size/2
grid_top_offset = 13
spr_offset = 2
null_block = -10

-- New disc
new_disc = {
    val = 1,
    curr_c = 1,
    to_c = 1,
}
move_speed = 0.02
possible_disc_vals = {1,2,3,4,5,6,7}
possible_new_disc_vals = {-2,1,2,3,4,5,6,7}
new_disc_bounce_timer = 0
new_disc_bounce_amp = 2
new_disc_bounce_speed = 60
new_disc_top_offset = 2

-- Rising row
drops_for_new_row = 7
drops_counter = 0

-- Dropping disc
drop_discs = {}
gravity = 0.05
found_hanging_discs = false

-- Clearing disc
clear_discs = {}
flash_dur = 30  -- number of frames to flash

-- Screenshake
shake = 0 
shake_amp = 3
shake_fade = 0.5

-- Scoring
score = 0
turn_score = 0
combo = 0
can_combo = true
score_timer = 0
score_delay = 20 -- delay before actually deduct the score
floating_txts = {}
combo_box_w = 20
combo_box_h = 10
combo_box_offset_y = 7
combo_box_offset_x = 8

-- Particles
smokes = {}
new_bg_line_timer = 0
trails = {}

-- Background lines
bg_lines = {}
bg_line_speed = 1
bg_line_length = 30

-- Flames
fires = {}
fire_speed = 0.007
fire_spread = 5
fire_life = 60


-- Debug
debug1 = fade_counter

function _init()
    for r=1,grid_size do
        for c=1,grid_size do
            grid[r][c] = 0
        end
    end
    new_disc.val = rnd(possible_new_disc_vals)
    music(0)
    -- Reset all the global tables and states
    drop_discs = {}
    clear_discs = {}
    floating_txts = {}
    smokes = {}
    fires = {}
    state = "dropping"
    score = 0
    turn_score = 0
    combo = 0
end

function _update60()
    new_bg_line_timer = (new_bg_line_timer + 1) % 361
    if (new_bg_line_timer % 20 == 0) make_bg_lines()
    dialog:update()
    debug1 = tut_stage

    if screen == "menu" then
        if (btnp(0) and modes == 1) then
            diff += 1
            sfx(2)
        end
        if (btnp(1) and modes == 1) then
            diff -= 1
            sfx(2)
        end
        if btnp(2) then
            modes -= 1
            sfx(2)
        end
        if btnp(3) then
            modes += 1
            sfx(2)
        end
        if (diff > 3) diff = 1
        if (diff < 1) diff = 3
        if (modes > 2) modes = 1
        if (modes < 1) modes = 2
        if (btnp(4) or btnp(5)) then
            next_screen = modes == 1 and "game" or "tutorial"
            transition_active = true
            drops_for_new_row = 7 * diff
            sfx(3)
            if (next_screen == "game") _init()
            if (next_screen == "tutorial") dialog:queue("you're playing in a 7x7 board, dropping new numbers to the grid and score as high as possible", function() init_tutorial() end)
        end
    elseif screen == "tutorial" then
        update_tutorial()
    elseif screen == "game" then
        screen_shake()
        update_smoke()
        if state == "control" then
            control()
        elseif state == "dropping" then
            find_hanging_discs()
            dropping_disc()
        elseif state == "clearing" then
            check_clearing()
            check_create_new_row()
        end
    elseif screen == "over" then
        for i=0,5 do
            if btnp(i) then
                next_screen = "menu"
                transition_active = true
                _init()
            end
        end
    end
end

function _draw()
    cls()    
    draw_bg_lines()
    if screen == "menu" then
        draw_menu()
    elseif screen == "tutorial" then
        draw_tutorial()
    elseif screen == "game" then
        draw_game_content()
    elseif screen == "over" then
        draw_over_content()
    end
    if transition_active then
        fade_counter += 0.25
        fade(flr(fade_counter))
        if fade_counter >= 9 then
            fade(flr(18-fade_counter))
            screen = next_screen
        end
        if fade_counter >= 18 then
            fade_counter = 0
            transition_active = false
        end
    end    
end

function draw_menu()
    local x, y, scale, w, h = 15, 20, 2, 48, 24
    for i=0,15 do
        pal(i, 1)
    end
    sspr(0, 16, w, h, x + wiggle(wavy_text_timer, 3, 90), y+scale, w*scale, h*scale)
    pal()
    sspr(0, 16, w, h, x + wiggle(wavy_text_timer, 3, 90), y, w*scale, h*scale)
    local diff_name = difficulties[diff]
    local diff_x = 42
    if (diff_name == "easy") then
        diff_col = 12
        diff_x = 44
    end
    if (diff_name == "normal") then
        diff_col =  9
        diff_x = 40
    end
    if (diff_name == "classic") then
        diff_col = 8
        diff_x = 37
    end
    if (modes == 1) prinx_wavy_shadow("< "..difficulties[diff].." >", diff_x, 77, diff_col, 1, 2, 45) else print_drop_shadow("< "..difficulties[diff].." >", diff_col + 35, 76, 13, 1)
    if (modes == 2) prinx_wavy_shadow("< how to play? >", 30, 87, 12, 1, 2, 45) else print_drop_shadow("how to play?", 42, 87, 13, 1)
    prinx_drop_shadow("press ❎ or 🅾️ to select", 105, 13, 1)
end

function draw_tutorial()
    
    if tut_stage > 0 then
        draw_grid()
        draw_combo()
        draw_drop_counter()
        -- draw_drop_discs()
        if (state == "control") draw_new_disc()
        if state == "dropping" then
            draw_drop_discs()
        elseif state == "clearing" then
            flash_n_clear_discs()
        end
    elseif tut_stage >= 1 then
        
    end

    draw_smokes()
    draw_trails()
    draw_floating_text()
    dialog:draw()
end

function update_tutorial()
    -- tut_stage = 3
    screen_shake()
    update_smoke()

    -- Stages of the tutorial
    if tut_stage > 0 then
        if state == "dropping" then
            find_hanging_discs()
            dropping_disc()
        elseif state == "clearing" then
            check_clearing()
            check_create_new_row()
        end
    end
    if tut_stage == 1 then
        if (not pause_tut_timer) tut_timer += 1
        if tut_timer == tut_wait then
            tut_timer = 0
            pause_tut_timer = true
            dialog:queue("every turn, you need to drop a new number into the grid. try moving it with left and right", function() tut_stage += 1 end)
        end
    end
    if tut_stage == 2 then
        if (tut_timer < 25) tut_timer += new_disc_move()
        if tut_timer > 25 then 
            tut_timer = 25
            dialog:queue("let's try to clear some numbers. drop the new number on the 4. the 4 will pop, because it's sitting in a 4-tall column\n\ndrop with z or x", function() tut_stage += 1 end)
        end
    end
    if tut_stage == 3 or tut_stage == 5 then
        if (not pause_tut_timer) tut_timer += 1
        new_disc.to_c = tut_stage
        new_disc.curr_c = move_towards(new_disc.curr_c, new_disc.to_c, move_speed*2)
        if (btnp(4) or btnp(5)) and new_disc.curr_c == new_disc.to_c and pause_tut_timer then
            make_drop_disc(new_disc.val, 0, tut_stage == 3 and 4 or 7, new_disc.curr_c)
            sfx(4)
            drops_counter += 1
            state = "dropping"
            new_disc.val = 3
            pause_tut_timer = false
            tut_timer = 0
            tut_stage += 1
        end
    end
    if tut_stage == 4 then
        if (not pause_tut_timer) tut_timer += 1
        if tut_timer == tut_wait then
            tut_timer = 0
            pause_tut_timer = true
            dialog:queue("how about rows? drop the 3 on the left of the 7. the new 3 will pop because it's on a 3-wide row.", function() tut_stage += 1 end)
        end
    end
    if tut_stage == 6 then
        if (not pause_tut_timer) tut_timer += 1
        if tut_timer == tut_wait then
            tut_timer = 0
            pause_tut_timer = true
            dialog:queue("those grays can break into random numbers when things next to them popped. drop these 3's on top of this gray to damage and break it", function() tut_stage += 1 end)
        end
    end
    if tut_stage == 7 or tut_stage == 8 then
        new_disc.to_c = 7
        new_disc.curr_c = move_towards(new_disc.curr_c, new_disc.to_c, move_speed*2)
        if (btnp(4) or btnp(5)) and new_disc.curr_c == new_disc.to_c and pause_tut_timer then
            make_drop_disc(new_disc.val, 0, 5, new_disc.curr_c)
                sfx(4)
            drops_counter += 1
            state = "dropping"
            new_disc.val = 3
            tut_timer += 1
            if (tut_stage == 8 and tut_timer > 1) pause_tut_timer = false
            tut_stage += 1
        end
    end
    if tut_stage == 9 then
        if (not pause_tut_timer) tut_timer += 1
        if tut_timer == tut_wait then
            tut_timer = 0
            pause_tut_timer = true
            dialog:queue("see those green bars on the grid's edge? those count your drops. once they're empty, a new row of grays will raise from the bottom. drop some more numbers and see!", function() tut_stage += 1 end)
        end
    end
    if tut_stage == 10 then
        new_disc_move()
        new_disc.curr_c = move_towards(new_disc.curr_c, new_disc.to_c, move_speed*2)
        if (btnp(4) or btnp(5)) and new_disc.curr_c == new_disc.to_c and pause_tut_timer then
            -- make_drop_disc(new_disc.val, 0, 5, new_disc.curr_c)
            for r=grid_size,1,-1 do
                if grid[r][new_disc.curr_c] == 0 then
                    sfx(4)
                    make_drop_disc(new_disc.val, 0, r, new_disc.curr_c)
                    new_disc.val = rnd(possible_new_disc_vals)
                    break
                end
            end
            drops_counter += 1
            state = "dropping"
            new_disc.val = 3
            tut_timer += 1
            if (drops_counter == 7) then
                pause_tut_timer = false
                tut_stage += 1
            end
        end
    end
    if tut_stage == 11 then
        if (not pause_tut_timer) tut_timer += 1
        if tut_timer == 3*tut_wait then
            tut_timer = 0
            pause_tut_timer = true
            dialog:queue("and that's the game! try to chain up combos for crazy highscore!", function() next_screen = "menu" transition_active = true end)
        end
    end
end

function draw_game_content()
    draw_grid()
    draw_combo()
    draw_trails()
    draw_drop_counter()
    draw_smokes()
    draw_floating_text()
    if state == "control" then
        draw_new_disc()
    elseif state == "dropping" then
        draw_drop_discs()
    elseif state == "clearing" then
        flash_n_clear_discs()
    end
end

function draw_over_content()
    local score_string = "score: "..tostr(score)
    local x = 59 - #score_string/2*4
    prinx_drop_shadow("game over!", 52, 7, 1)
    prinx_wavy_shadow(score_string, x, 65, diff_col, 1, 2, 45)
    prinx_drop_shadow("press any button to restart!", 100, 7, 1)
end

function init_tutorial()
    tut_stage = 1
    grid = {
        {0,0,0,0,0,0,0},
        {0,0,0,0,0,0,0},
        {0,-2,4,0,0,7,0},
        {0,0,2,0,0,0,-2},
        {0,0,-1,0,0,0,0},
        {0,0,0,0,0,0,7},
        {0,0,0,0,0,0,0},
    }
    new_disc.val = 5
    new_disc.curr_c = 3
    new_disc.to_c = 3
    drops_for_new_row = 7
end

-->8
-- control & physics
function control()
    new_disc_move()


    -- Dropping
    if (btnp(4) or btnp(5)) and new_disc.curr_c == new_disc.to_c then
        if (grid[1][new_disc.curr_c] ~= 0) then
            next_screen = "over"
            transition_active = true
        end
        -- Find the highest avalailable space under the new disc
        for r=grid_size,1,-1 do
            if grid[r][new_disc.curr_c] == 0 then
                sfx(4)
                make_drop_disc(new_disc.val, 0, r, new_disc.curr_c)
                new_disc.val = rnd(possible_new_disc_vals)
                break
            end
        end
        state = "dropping"
        found_hanging_discs = false
        drops_counter += 1
    end
end

function new_disc_move()
    local move_disc = 0
    if btnp(0) then
        sfx(0)
        new_disc.to_c -= 1
    elseif btnp(1) then
        sfx(0)
        new_disc.to_c += 1
    end
    if new_disc.to_c < 1 then new_disc.to_c = 7 end
    if new_disc.to_c > 7 then new_disc.to_c = 1 end

    -- Smooth movement
    new_disc.curr_c = move_towards(new_disc.curr_c, new_disc.to_c, move_speed*2)

    return abs(new_disc.curr_c - new_disc.to_c)
end

function find_hanging_discs()
    if found_hanging_discs then return end
    for c=1,grid_size do
        -- Collect current column elements
        local col_elems = {}
        for r=grid_size,1,-1 do
            add(col_elems, grid[r][c], 1)
        end
        
        -- Extract non-zero elements
        local non_zero = {}
        for i=grid_size,1,-1 do
            if col_elems[i] ~= 0 then
                add(non_zero, col_elems[i], 1)
            end
        end
        
        -- Build new column with zeros followed by non-zero elements
        local num_zeros = grid_size - #non_zero
        for i=1,num_zeros do
            add(non_zero, 0, 1)
        end

        -- See if this col actually have any hanging discs
        if lists_equal(col_elems, non_zero) then goto next_col end
        
        -- Track displacement for each moved disc
        for to_r=1,grid_size do
            for from_r=1,grid_size do
                if non_zero[to_r] == 0 then goto continue end
                if non_zero[to_r] ~= 0 and non_zero[to_r] == col_elems[from_r] then
                    grid[from_r][c] = 0
                    make_drop_disc(
                        non_zero[to_r],
                        from_r,
                        to_r,
                        c
                    )
                    col_elems[from_r] = 0
                    goto continue
                end
            end
            ::continue::
        end
        ::next_col::
    end
    found_hanging_discs = true
end

function dropping_disc()
    for _,disc in pairs(drop_discs) do
        if (disc.curr_r <= grid_size and disc.curr_r >= 1 and disc.curr_r == flr(disc.curr_r)) grid[disc.curr_r][disc.c] = 0
        disc.curr_r = move_towards(disc.curr_r, disc.to_r, gravity)
        -- Trailing
        for i=1,4 do
            if (disc.to_r-disc.curr_r > 0.25) make_trail(grid_offset+disc.c*(tile_size+0.25)+spr_offset+i, grid_offset+(disc.curr_r-0.2)*tile_size+grid_top_offset, get_color_of_disc(disc.val))
        end
        if disc.curr_r == disc.to_r then
            if (disc.val ~= 0) make_smoke(disc.c*(tile_size+0.5)+grid_offset+2*spr_offset, (disc.to_r+1)*tile_size+grid_offset+grid_top_offset, 1)
            if disc.bounces ~= 0 then
                if (disc.bounces > 1) sfx(1)
                shake = 1
                disc.curr_r = disc.to_r - 0.25 * disc.bounces
                disc.bounces -= 1
            else
                grid[disc.to_r][disc.c] = disc.val
                del(drop_discs, disc)
            end
        end
    end
    if (#drop_discs == 0) state = "clearing"
end

function move_towards(current, target, speed)
    if current == target then return current end
    local t = speed * 2
    local diff = target - current
    local progress = min(1, t)
    
    -- Quadratic ease-out (starts slow, ends fast)
    local ease_out = 1 - (1 - progress) * (1 - progress)
    
    -- Snap to target when close
    local new_value = current + diff * ease_out
    if abs(target - new_value) < 0.1 then
        new_value = target
    end
    
    return new_value
end

function check_clearing()
    if (#clear_discs > 0) return
    for r=grid_size,1,-1 do
        for c=grid_size,1,-1 do
            if (grid[r][c] == 0) goto continue
            local rows, cols = 0, 0
            -- Counting the cols
            for l_c=c,1,-1 do
                if (grid[r][l_c] == 0) goto count_r_cols else cols += 1
            end
            ::count_r_cols::
            if (c == grid_size) goto count_rows
            for r_c=c+1,grid_size do
                if (grid[r][r_c] == 0) goto count_rows else cols += 1
            end

            -- Counting the rows
            ::count_rows::
            for row=grid_size,1,-1 do
                if (grid[row][c] == 0) goto check_clear else rows += 1
            end
            
            -- Clearing discs
            ::check_clear::
            if rows == grid[r][c] or cols == grid[r][c] then
                make_clear_disc(grid[r][c], r, c)
                grid[r][c] = null_block
                if (combo == 0) sfx(5)
                if (combo == 1) sfx(6)
                if (combo == 2) sfx(7)
                if (combo == 3) sfx(8)
                if (combo >= 4) sfx(9)
            end
            ::continue::
        end 
    end
    if (#clear_discs == 0) state = "control"
end

function check_create_new_row()
    -- Skip check if not done clearing or not enough drops
    if (drops_counter < drops_for_new_row or #clear_discs > 0) return
    drops_counter = 0
    -- Check if top row is filled?
    for c=1,grid_size do
        if grid[1][c] ~= 0 then
            -- game over
            next_screen = "over"
            transition_active = true
            return
        end
    end
    -- Move all other rows up 1
    for c=1,grid_size do
        for r=2,grid_size do
            make_drop_disc(grid[r][c], r, r-1, c)
        end
        -- New gray row at bottom
        make_drop_disc(-2, 8, 7, c)
    end
    state = "dropping"
end

function check_gray_discs(r, c)
    -- Check left
    if (c > 1 and grid[r][c-1] < 0) then
        grid[r][c-1] += 1
        if (grid[r][c-1] == 0) then 
            grid[r][c-1] = rnd(possible_disc_vals)
            make_smoke((c-1)*(tile_size+0.5)+grid_offset+2*spr_offset, (r+0.5)*tile_size+grid_offset+grid_top_offset, 6)
            sfx(1)
        end
    end
    -- Check right
    if (c < grid_size and grid[r][c+1] < 0) then
        grid[r][c+1] += 1
        if (grid[r][c+1] == 0) then
            grid[r][c+1] = rnd(possible_disc_vals)
            make_smoke((c+1)*(tile_size+0.5)+grid_offset+2*spr_offset, (r+0.5)*tile_size+grid_offset+grid_top_offset, 6)
            sfx(1)
        end
    end
    -- Check up
    if (r > 1 and grid[r-1][c] < 0) then
        grid[r-1][c] += 1
        if (grid[r-1][c] == 0) then
            grid[r-1][c] = rnd(possible_disc_vals)
            make_smoke((c)*(tile_size+0.5)+grid_offset+2*spr_offset, (r-0.5)*tile_size+grid_offset+grid_top_offset, 6)
            sfx(1)
        end
    end
    -- Check down
    if (r < grid_size and grid[r+1][c] < 0) then
        grid[r+1][c] += 1
        if (grid[r+1][c] == 0) then
            grid[r+1][c] = rnd(possible_disc_vals)
            make_smoke((c)*(tile_size+0.5)+grid_offset+2*spr_offset, (r+1.5)*tile_size+grid_offset+grid_top_offset, 6)
            sfx(1)
        end
    end
end

function update_smoke() 
    for _,smoke in pairs(smokes) do
        smoke.life -= 1
        smoke.x = move_towards(smoke.x, smoke.to_x, smoke.speed)
        smoke.y = move_towards(smoke.y, smoke.to_y, smoke.speed)
        if (smoke.life <= 0) del(smokes, smoke)
    end
end
-->8
-- draw & animation


function fade(i)
    for c=0,15 do
        if flr(i+1)>=10 then
            pal(c,0,1)
        else
            pal(c,fade_table[c+1][flr(i+1)],1)
        end
    end
end

function draw_grid()
    rectfill(grid_offset+tile_size, grid_offset+tile_size+grid_top_offset, grid_offset+line_length, grid_offset+line_length+grid_top_offset, 0)
    for row=1,grid_size do
        local gap = (row + 1) * tile_size

        line(tile_size + grid_offset, grid_offset + tile_size+grid_top_offset, line_length + grid_offset, grid_offset + tile_size+grid_top_offset, 1)
        line(tile_size + grid_offset, grid_offset + tile_size+grid_top_offset, grid_offset + tile_size, line_length + grid_offset+grid_top_offset, 1)
        line(tile_size + grid_offset, gap + grid_offset+grid_top_offset, line_length + grid_offset, gap + grid_offset+grid_top_offset, 1)
        line(grid_offset + gap, tile_size + grid_offset+grid_top_offset, grid_offset + gap, line_length + grid_offset+grid_top_offset, 1)
        for col=1,grid_size do
            if grid[row][col] > 0 and grid[row][col] ~= null_block then
                spr(grid[row][col], col*tile_size+spr_offset+grid_offset, row*tile_size+spr_offset+grid_offset+grid_top_offset)
            end
            if (grid[row][col] == -2) spr(8, col*tile_size+spr_offset+grid_offset, row*tile_size+spr_offset+grid_offset+grid_top_offset)
            if (grid[row][col] == -1) spr(9, col*tile_size+spr_offset+grid_offset, row*tile_size+spr_offset+grid_offset+grid_top_offset)
        end
    end
end

function draw_new_disc() 
    local val, c = new_disc.val, new_disc.curr_c
    new_disc_bounce_timer = (new_disc_bounce_timer + 1) % 361
    spr(val, c*tile_size + spr_offset + grid_offset, new_disc_top_offset + grid_offset + wiggle(new_disc_bounce_timer, new_disc_bounce_amp, new_disc_bounce_speed)+grid_top_offset)
    if (val == -2) spr(8, c*tile_size + spr_offset + grid_offset, new_disc_top_offset + grid_offset + wiggle(new_disc_bounce_timer, new_disc_bounce_amp, new_disc_bounce_speed)+grid_top_offset)
    -- Ghost piece
    for r=grid_size,1,-1 do
        if grid[r][flr(c)] == 0 then
            for col=0,15 do
                pal(col, 1)
            end
            spr(val, c*tile_size + spr_offset +grid_offset, r*tile_size+spr_offset+grid_offset+grid_top_offset)
            if (val == -2) spr(8, c*tile_size + spr_offset +grid_offset, r*tile_size+spr_offset+grid_offset+grid_top_offset)
            pal()
            break
        end
    end
end

function draw_drop_discs() 
    for _,disc in pairs(drop_discs) do
        if (disc.val ~= 0) spr(disc.val, disc.c*tile_size + spr_offset +grid_offset, disc.curr_r*tile_size + spr_offset +grid_offset+grid_top_offset)
        if (disc.val == -2) spr(8, disc.c*tile_size + spr_offset +grid_offset, disc.curr_r*tile_size + spr_offset +grid_offset+grid_top_offset)
    end 
end

function flash_n_clear_discs()
    if (#clear_discs == 0) return
    if can_combo then
        combo += 1
        can_combo = false
    end
    for _,disc in pairs(clear_discs) do
        r, c = disc.r, disc.c
        disc.flash_dur -= 1
        if (disc.flash_dur % 5 == 0) then
            spr(disc.val, c*tile_size+spr_offset +grid_offset, r*tile_size+spr_offset+grid_offset+grid_top_offset)
        end
        if disc.flash_dur == 0 then
            -- score += disc.val * combo
            make_floating_text(
                disc.val,
                12,
                -- 7,
                grid_offset + c*tile_size + spr_offset,
                grid_offset + r*tile_size + grid_top_offset - 1,
                grid_offset + r*tile_size + grid_top_offset - 6
            )
            grid[r][c] = 0
            check_gray_discs(r, c)
            del(clear_discs, disc)
        end
    end

    if #clear_discs == 0 then
        state = "dropping"
        can_combo = true
        found_hanging_discs = false
    end
end

function draw_drop_counter()
    local remain = drops_for_new_row - drops_counter
    for i=1,drops_for_new_row do
        if (i<8) spr(19, grid_offset+line_length,grid_offset+tile_size*i+spr_offset+grid_top_offset) 
        if (i>7 and i<15) spr(17, spr_offset+grid_offset+tile_size*(i-7), grid_offset+line_length+grid_top_offset)
        if (i>14) spr(19, grid_offset+tile_size/2-1, grid_offset+tile_size*(i-14)+spr_offset+grid_top_offset) 
    end
    for i=1,remain do
        if (i<8) spr(20, grid_offset+line_length,grid_offset+tile_size*i+spr_offset+grid_top_offset) 
        if (i>7 and i<15) spr(18, spr_offset+grid_offset+tile_size*(7-i)+line_length, grid_offset+line_length+grid_top_offset)
        if (i>14) spr(20, grid_offset+tile_size/2-1, grid_offset+tile_size*(14-i)+spr_offset+line_length+grid_top_offset)
        
    end
end

function draw_floating_text()
    for _,txt in pairs(floating_txts) do
        print("+"..tostr(txt.val), txt.x, txt.curr_y, txt.color)
        txt.curr_y = move_towards(txt.curr_y, txt.to_y, txt.speed)

        if txt.curr_y == txt.to_y then
            if txt.linger ~= 0 then
                txt.linger -= 1
            else
                turn_score += txt.val
                del(floating_txts, txt)
            end
        end
    end
    if #floating_txts == 0 and combo ~= 0 and turn_score ~= 0 then
        score_timer += 1
        if (score_timer < score_delay) return
        score += combo
        turn_score -= 1
        sfx(10)
        if (turn_score == 0) then
            combo = 0 
            score_timer = 0
        end
    end
end

function draw_smokes()
    for _,smoke in pairs(smokes) do
        circfill(smoke.x, smoke.y, smoke.r, smoke.color)
    end
end

function draw_trails()
    for _,t in pairs(trails) do
        circfill(t.x, t.y, t.r, t.c)
        t.life -= 1
        if (t.life <= 0) del(trails, t)
    end
end

function draw_bg_lines()
    for _,bg_line in pairs(bg_lines) do
        local x, y, l, spd = bg_line.x, bg_line.y, bg_line.length, bg_line.speed
        local speed_x, speed_y = bg_line.dir_x * spd, bg_line.dir_y * spd
        bg_line.x += speed_x
        bg_line.y += speed_y
        local offset_1, offset_2 = 6+rnd(3), 2+rnd(2)
        line(x,y, x-speed_x*l, y-speed_y*l, 1)
        line(x,y, x-speed_x*offset_1, y-speed_y*offset_1, 2)
        line(x,y, x-speed_x*offset_2, y-speed_y*offset_2, 5)
        line(x,y,x,y,rnd({7,10}))
        if (x+l<0 or x-l>128 or y+l<0 or y-l>128) del(bg_lines, bg_line)
    end
end

function screen_shake()
    local shakex = (shake_amp-rnd(shake_amp * 2)) * shake
    local shakey = (shake_amp-rnd(shake_amp * 2)) * shake
    camera(shakex, shakey)
    shake = shake * shake_fade
    if (shake<0.1) shake=0
end

function draw_combo()
    -- Spawn the fire
    local fire_per_box = combo * 5
    if (new_bg_line_timer % 15 == 0) then
        for i=1,fire_per_box do
            make_fire(
                128-combo_box_offset_x-combo_box_w+1+(combo_box_w-2)/fire_per_box*i-2,
                combo_box_offset_y,
                8
            )
            make_fire(
                128-combo_box_offset_x-combo_box_w*2+1-6+(combo_box_w-2)/fire_per_box*i-2,
                combo_box_offset_y,
                12
            )
            make_fire(
                combo_box_offset_x+1+(1.5*combo_box_w-2)/fire_per_box*i-2,
                combo_box_offset_y,
                3
            )
        end
    end

    -- Fire!
    draw_fire()

    -- Total score box
    rectfill_bor(combo_box_offset_x, combo_box_offset_y+1, combo_box_offset_x+combo_box_w*1.5, combo_box_offset_y+1+combo_box_h, 1)
    rectfill_bor(combo_box_offset_x, combo_box_offset_y, combo_box_offset_x+combo_box_w*1.5, combo_box_offset_y+combo_box_h, 3)

    -- Combo boxes
    rectfill_bor(128-combo_box_offset_x-combo_box_w, combo_box_offset_y+1, 128-combo_box_offset_x, combo_box_offset_y+1+combo_box_h, 1)
    rectfill_bor(128-combo_box_offset_x-combo_box_w*2-6, combo_box_offset_y+1, 128-combo_box_offset_x-combo_box_w-6, combo_box_offset_y+1+combo_box_h, 1)
    -- Red
    rectfill_bor(128-combo_box_offset_x-combo_box_w, combo_box_offset_y, 128-combo_box_offset_x, combo_box_offset_y+combo_box_h, 8)
    -- Blue
    rectfill_bor(128-combo_box_offset_x-combo_box_w*2-6, combo_box_offset_y, 128-combo_box_offset_x-combo_box_w-6, combo_box_offset_y+combo_box_h, 12)
    print_drop_shadow("x", 96, combo_box_offset_y+3, 8, 1)

    -- Total score
    center_print(tostr(score), combo_box_offset_x+combo_box_w*0.75, combo_box_offset_y+4, 1)
    center_print(tostr(score), combo_box_offset_x+combo_box_w*0.75, combo_box_offset_y+3, 7)

    -- Combo
    print(tostr(combo), 128-combo_box_offset_x-combo_box_w+2, combo_box_offset_y+4, 1)
    print(tostr(combo), 128-combo_box_offset_x-combo_box_w+2, combo_box_offset_y+3, 7)

    -- Turn score
    right_print(tostr(turn_score), 128-combo_box_offset_x-combo_box_w-6, combo_box_offset_y+4, 1)
    right_print(tostr(turn_score), 128-combo_box_offset_x-combo_box_w-6, combo_box_offset_y+3, 7)
end

function draw_fire()
    for _,f in pairs(fires) do 
        local f_c, r = 1, f.start_r
        if (f.life < 0.7*fire_life) then
            f_c = 2
            r = 3
        end
        if (f.life < 0.4*fire_life) then
            f_c = 3
            r = 4
        end
        f.x = move_towards(f.x, f.t_x, f.speed)
        f.y = move_towards(f.y, f.t_y, f.speed)
        circfill(f.x, f.y, r, f.c_set[f_c])
        f.life -= 1
        if (f.life <= 0) del(fires, f)
    end
end

-->8
-- Utils
function start_transition(next_screen)  
    next_screen = next_screen
    prev_screen = screen
end

function prinx(text, y, color)
    print(text,64-#text*2,y,color)
end

function print_drop_shadow(t, x, y, c, s_c)
    print(t, x, y+1, s_c)
    print(t, x, y, c)
end

function prinx_drop_shadow(text, y, color, shadow)
    local x = 64-#text*2
    print_drop_shadow(text, x, y, color, shadow)
end

function prinx_wavy_shadow(text, x, y, color, shadow, amplitude, speed)
    wavy_text_timer = (wavy_text_timer + 1) % 361
    for i=0,#text do
        local x = x + i*4
        local w = wiggle(wavy_text_timer+i, amplitude, speed)
        local t = sub(text,i,i)
        print_drop_shadow(t, x, y+w, color, shadow)
    end
end

function make_drop_disc(val, curr_r, to_r, c)
    add(drop_discs, {
        val = val,
        curr_r = curr_r,
        to_r = to_r,
        c = c,
        bounces = 2,
    })
end

function lists_equal(list1, list2)
    -- Check if lengths are different
    if #list1 ~= #list2 then
        return false
    end
    
    -- Compare each element
    for i=1,#list1 do
        if list1[i] ~= list2[i] then
            return false
        end
    end
    
    -- All elements match
    return true
end

function make_clear_disc(val, curr_r, curr_c)
    add(clear_discs, {
        val = val,
        r = curr_r,
        c = curr_c,
        flash_dur = flash_dur
    })
end

function make_fire(x, y, col)
    local c_set = {}
    if (col == 3) c_set = {3, 5, 1}
    if (col == 8) c_set = {8, 9, 2}
    if (col == 12) c_set = {12, 5, 1}
    -- c_set = {7,7,7}
    add(fires, {
        x = x,
        y = y,
        c_set = c_set,
        t_x = x + fire_spread - rnd(2*fire_spread),
        t_x = x,
        t_y = y - rnd(3*fire_spread),
        start_r = rnd({1,1,2}),
        speed = fire_speed,
        life = fire_life
    })
end

function make_floating_text(val, c, x, curr_y, to_y)
    add(floating_txts, {
        val = val,
        color = c, 
        x = x,
        curr_y = curr_y,
        to_y = to_y,
        speed = 0.1,
        linger = 40 -- number of frames to linger after reaching
    })
end

function make_smoke(x, y, num)
    local cols = {5,6,7,13} 
    local radii = {1,2}
    for i=1,num do
        local w = 3
        local x_offset = w - rnd(2*w)
        add(smokes, {
            r = rnd(radii),
            x = x + x_offset,
            y = y,
            to_x = x + 2*x_offset,
            to_y = y - rnd(5),
            speed = rnd(0.2),
            life = 15 + rnd(10),
            color = rnd(cols),
        })
    end
end

function make_trail(x, y, c)
    add(trails, {
        x = x,
        y = y,
        c = c,
        r = rnd({0.5,1}),
        life = 2 + rnd(5),
    })
end

function make_bg_lines()
    local start = rnd({"u", "d", "l", "r"})
    if (start == "u") then 
        add(bg_lines, {
            x = 2+rnd(126),
            y = 0,
            speed = bg_line_speed + rnd(bg_line_speed),
            dir_x = 0,
            dir_y = 1,
            star = 7, -- color of the main star
            length = bg_line_length + rnd(20), -- length of trail
        })
    end
    if (start == "d") then
        add(bg_lines, {
            x = 2+rnd(126),
            y = 128,
            speed = bg_line_speed + rnd(bg_line_speed),
            dir_x = 0,
            dir_y = -1,
            star = 7,
            length = bg_line_length + rnd(20), -- length of trail
        })
    end
    if (start == "l") then
        add(bg_lines, {
            x = 0,
            y = 2+rnd(126),
            speed = bg_line_speed + rnd(bg_line_speed),
            dir_x = 1,
            dir_y = 0,
            star = 7,
            length = bg_line_length + rnd(20), -- length of trail
        })
    end
    if (start == "r") then
        add(bg_lines, {
            x = 128,
            y = 2+rnd(126),
            speed = bg_line_speed + rnd(bg_line_speed),
            dir_x = -1,
            dir_y = 0,
            star = 7,
            length = bg_line_length + rnd(20), -- length of trail
        })
    end
end

function get_color_of_disc(val)
    if (val == 1) return 11
    if (val == 2) return 10
    if (val == 3) return 9
    if (val == 4) return 8
    if (val == 5) return 14
    if (val == 6) return 12
    if (val == 7) return 4
    if (val == -2 or val == -1) return 13
end

function wiggle(timer, amp, speed)
    return amp*sin(timer/speed)
end

function rectfill_bor(x1, y1, x2, y2, col)
    rectfill(x1+1, y1, x2-1, y2, col)
    rectfill(x1, y1+1, x2, y2-1, col)
end

function center_print(t, x, y, col)
    local w = x - #t/2*3
    print(t, w, y, col)
end

function right_print(t, x, y, col)
    local w = x - #t*4
    print(t, w, y, col)
end
__gfx__
000000000000030007aaaa000aaaaa00eeee00e27eeeeee80777cc10994444420077770000777700c111722271c1727271717272717172720000000011112222
00000000000073007aa900a9a9999994e88200e27ee800007cccccc19440044207ddddd00700006011112222111122221c112722171c27270000000011112222
007007000007b300aaa900a9a9940094e88200e207eeee807cc10000000044207dddddd5700dd005111122c21171c27271717272717172720000000011112222
00077000007bb300999900a944440094e88200e2000000e87cc10000000942007dddddd570dddd0511112222111122221111222c11172c270000000011112222
0007700007bbb300000000a900000494e88200e27ee800e87ccccc10000942007dddddd570ddd5057c727771777c777777777777777777770000000022221111
0070070000bbb300077aaa9000000094022888827ee800e8ccc100c1000942007dddddd5700d50052727171727271717c727771777c777770000000022221111
0000000000bbb3007aa90000aa990094000000e27ee800e8ccc100c1000942000ddddd50060000507272717c72777c7777777777777777770000000022221111
00000000003333000999999904444440000000e20888888001cccc100009420000555500005555002727171727271717272717c72777c7770000000022221111
00000000000000000000000000001000000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000011000000330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000011000000330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000011111110333333300011000000330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000111111103333333000011000000330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000011000000330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000011000000330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000010000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000077bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000077bbbbb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00007bb0000bb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000bbb000000b0000000000000000000000000a99994444200000000000000000000000000000000000000000000000000000000000000000000000000000000
00bbb3000000b000000000000000000000000a944444004200000000000000000000000000000000000000000000000000000000000000000000000000000000
0bbb33000000b000000000a900000000000009444400044000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbb00330000b300000000a9900000000000000440000044000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbb003b00bb3000000000a9000000000000000000000042000000000000000000000000000000000000000000000000000000000000000000000000000000000
0bb000bb033000000000a90000000000000000000000940000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000bb000000000000900000000000000000000000920000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000bb000007a0000990000ee880000770ccc00000420000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000bb00000aa0000990e0e802200007cc000c0009420000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000bb000000000aa990088000000000cc000cc004400000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000bb0007a000a00990088000066e00cc000cc004400000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000bb0007a009900090088000ee00e00cc00cc002400000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000b300aa0009900094088000e000e00cc0cd0024400000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000b3000aa0009900094088800e000e00ccdd00024400000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000b3000aa0009940044008800e00ee00cc0000022400000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000b300009a9000994404008200eeee800cc0000022220000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000999000990044022000e88000c00000022220000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000cc00000002200000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000cd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000cd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000077bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000077bbbbb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00007bb0000bb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000bbb000000b0000000000000000000000000000094444200000000000000000000000000000000000000000000000000000000000000000000000000000000
00bbb3000000b0000000000000000000000000099944004200000000000000000000000000000000000000000000000000000000000000000000000000000000
0bbb33000000b0000000000000000000000000994440044000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbb00330000b30000000000000000000000000944400044000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbb003b00bb300000000000000000000000000044000042000000000000000000000000000000000000000000000000000000000000000000000000000000000
0bb000bb033000000000000000000000000000000000940000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000bb000000000000000000000000000000000000920000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000bb000007a000000000000000000770ccc00000420000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000bb00000aa0000000000000000007cc000c0009420000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000bb000000000aaa00000000000000cc000cc004400000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000bb0007a000a00090000000066e00cc000cc004400000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000bb0007a009900000000000ee00e00cc00cc002400000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000b300aa0009900000000000e000e00cc0cd0024400000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000b3000aa0009900000000000e000e00ccdd00024400000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000b3000aa0009940004000000e00ee00cc0000022400000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000b300009a9000994444000000eeee800cc0000022220000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000999000999400000000e88000c00000022220000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000cc00000002200000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000cd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000cd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000a55522222222211111111111111111111111111111111111111111111111111111111111111111000
000000000000000000000000000007777bbbb0000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000007777bbbb0000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000007777bbbbbbbbbb00000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000007777bbbbbbbbbb00000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000077bbbb11111111bbbb000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000077bbbb11111111bbbb000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000bbbbbb110000000011bb00000000100000000000000000000000000000000000000000aa99999999444444442200000000000000000
000000000000000000000bbbbbb110000000011bb00000000100000000000000000000000000000000000000000aa99999999444444442200000000000000000
0000000000000000000bbbbbb33000000000000bb000000001000000000000000000000000000000000000000aa9944444444441111442200000000000000000
0000000000000000000bbbbbb33000000000000bb000000001000000000000000000000000000000000000000aa9944444444441111442200000000000000000
00000000000000000bbbbbb3333000000000000bb000000001000000000aa9900000000000000000000000000994444444411110044441100000000000000000
00000000000000000bbbbbb3333000000000000bb000000001000000000aa9900000000000000000000000000994444444411110044441100000000000000000
000000000000000bbbbbb1111333300000000bb330000000010000000aa999900000000000000000000000000114444111100000044440000000000000000000
000000000000000bbbbbb1111333300000000bb330000000010000000aa999900000000000000000000000000114444111100000044440000000000000000000
000000000000000bbbbbb000033bb0000bbbb33110000000010000000aa991100000000000000000000000000001111000000000044220000000000000000000
000000000000000bbbbbb000033bb0000bbbb33110000000010000000aa991100000000000000000000000000001111000000000044220000000000000000000
00000000000000011bbbb000011bbbb003333110000000000100000aa99110000000000000000000000000000000000000000009944110000000000000000000
00000000000000011bbbb000011bbbb003333110000000000100000aa99110000000000000000000000000000000000000000009944110000000000000000000
000000000000000001111000000bbbb0011110000000000001000009911000000000000000000000000000000000000000000009922000000000000000000000
000000000000000001111000000bbbb0011110000000000001000009911000000000000000000000000000000000000000000009922000000000000000000000
000000000000000000000000000bbbb000000000077aa00001000999900000000eeee888800000000777700cccccc00000000004422000000000000000000000
000000000000000000000000000bbbb000000000077aa00001000999900000000eeee888800000000777700cccccc00000000004422000000000000000000000
000000000000000000000000000bbbb0000000000aaaa00001000999900ee00ee881122220000000077cccc111111cc000000994422000000000000000000000
000000000000000000000000000bbbb0000000000aaaa00001000999900ee00ee881122220000000077cccc111111cc000000994422000000000000000000000
000000000000000000000000000bbbb000000000011110000aaaa999900118888110011110000000011cccc000000cccc0000444411000000000000000000000
000000000000000000000000000bbbb000000000011110000aaaa999900118888110011110000000011cccc000000cccc0000444411000000000000000000000
000000000000000000000000000bbbb00000077aa000000aa1111999900008888000000006666ee0000cccc000000cccc0000444400000000000000000000000
000000000000000000000000000bbbb00000077aa000000aa1111999900008888000000006666ee0000cccc000000cccc0000444400000000000000000000000
000000000000000000000000000bbbb00000077aa000099991000119900008888000000eeee1111ee0011cccc0000cccc0000224400000000000000000000000
000000000000000000000000000bbbb00000077aa000099991000119900008888000000eeee1111ee0011cccc0000cccc0000224400000000000000000000000
000000000000000000000000000bb330000aaaa11000099991000009944008888000000ee110000ee0000cccc00ccdd110022444400000000000000000000000
000000000000000000000000000bb330000aaaa11000099991000009944008888000000ee110000ee0000cccc00ccdd110022444400000000000000000000000
0000000000000000000000000bb33110000aaaa00000099991000009944008888880000ee000000ee0000ccccdddd11000022444400000000000000000000000
0000000000000000000000000bb33110000aaaa00000099991000009944008888880000ee000000ee0000ccccdddd11000022444400000000000000000000000
0000000000000000000000000bb33000000aaaa00000099994400004444001188880000ee0000eeee0000cccc111100000022224400000000000000000000000
0000000000000000000000000bb33000000aaaa00000099994400004444001188880000ee0000eeee0000cccc111100000022224400000000000000000000000
00000000000000000000000bb331100000099aa99000011999944441144000088220000eeeeeeee880000cccc000000000022222222000000000000000000000
00000000000000000000000bb331100000099aa99000011999944441144000088220000eeeeeeee880000cccc000000000022222222000000000000000000000
0000000000000000000000011110000000011999999000011999911004444002222000011ee8888110000cc11000000000022222222000000000000000000000
0000000000000000000000011110000000011999999000011999911004444002222000011ee8888110000cc11000000000022222222000000000000000000000
00000000000000000000000000000000000001111110000001111000011110011110000001111110000cccc00000000000011222211000000000000000000000
00000000000000000000000000000000000001111110000001111000011110011110000001111110000cccc00000000000011222211000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000000ccdd00000000000000111100000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000000ccdd00000000000000111100000000000000000000000
000000000000000000000000000000000000000000000000010000000000000000000000000000000ccdd1100000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000010000000000000000000000000000000ccdd1100000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000011110000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000011110000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000d00000ddd0ddd00dd0d0d00000d0000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000d100000d110d1d0d110d0d000001d000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000d1100000dd00ddd0ddd0ddd0000001d00000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000001d100000d100d1d011d011d000000d100000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000001d00000ddd0d0d0dd10ddd00000d1000000007000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000001110101011001110000010000000005000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000000005000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000000005000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000000002000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000c0c00000ccc00cc00000ccc0c000ccc0c0c2ccc00000c000000000000000000000000000000000
000000000000000000000000000000000000000000c0c00cc0c0c000001c10c1c00000c1c0c000c1c0c0c211c000001c00000000000000000000000000000000
000000000000000000000000000000000000c00000c0c0c1c0c0c000000c00c0c00000ccc0c000ccc0ccc20cc0000001c0000000000000000000000000000000
00000000000000000000000000000000000c100000ccc0c0c0ccc000000c00c0c00000c110c000c1c011c2011000000c10000000000000000000000000000000
0000000000000000000000000000000000c1000000c1c0c0c0ccc000000c00cc100000c000ccc0c0c0ccc20c000000c100000000000000000000000000000000
00000000000000000000000000000000001c000000c0c0cc10111000000100110000001000111010101112010000001000000000000000000000000000000000
000000000000000000000000000000000001c0000010101100000000000000000000000000000000000002000000000000000000000000000000000000000000
00000000000000000000000000000000000010000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000
00000000000000000000ddd0ddd0ddd00dd00dd000000ddddd0000000dd0ddd000000ddddd000000ddd00dd000000dd0ddd0d000ddd00dd0ddd0000000000000
00000000000000000000d1d0d1d0d110d110d1100000dd1d1dd00000d1d0d1d00000dd111dd000001d10d1d00000d110d110d000d110d1101d10000000000000
00000000000000000000ddd0dd10dd00ddd0ddd00000ddd1ddd00000d0d0dd100000dd0d0dd000000d00d1d00000ddd0dd00d000dd00d0000d00000000000000
00000000000000000000d110d1d0d10011d011d00000dd1d1dd00000d0d0d1d00000dd010dd000000d00d1d0000011d0d100d000d100d0000d00000000000000
00000000000000000000d000d0d0ddd0dd10dd1000001ddddd100000dd10d0d000001ddddd1000000d00dd100000dd10ddd0ddd0ddd01dd00d00000000000000
00000000000000000000100010101110110011000000011111000000110010100000011111000000010011000000110011101110111001100100000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000700000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000500000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000500000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000500000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000500000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000500000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000500000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000200000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000200000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000200000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000200000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000200000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000200000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000100000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000100000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000100000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000100000000

__sfx__
0104000000140021500315001150001400014000100001002100015100250001710002000240001a1001d100300002110023100000000000027100360002a1002b1002d1002e1003010032100331000000000000
010400002b630186300f620046100e60006600026000e600086000160001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010300002554020530000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01050000065200b5301b5403054030500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0102000000610006100061001610066100a61012610226203663017600246003860000600026003a400245002c5003e5003a60000000000000000000000000000000000000000000000000000000000000000000
010200000373008740107500373006740117501c7500b730147401d7502b7503710011000350002f000280000000000000000000000009000130001f000000000000000000000000000000000000000000000000
01020000037300874011750087300e7401775022750107301874023750317503710011000350002f000280000000000000000000000009000130001f000000000000000000000000000000000000000000000000
01020000057300e740157500a730127401a75023750107301b740257503575011000350002f000280000000000000000000000009000130001f00000000000000000000000000000000000000000000000000000
01020000087300e740187500a730127401d75028750137301f7402c7503a7503710011000350002f000280000000000000000000000009000130001f000000000000000000000000000000000000000000000000
010200000b730157401e7500a7301774023750307501b73025740327503f7503710011000350002f000280000000000000000000000009000130001f000000000000000000000000000000000000000000000000
01010000357403a740000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00030000250502b050240502605028050290502a0502b0502c0502d0502e0502f0503005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
051400200c0433f2151b3133f415246150c0433f3151b3130c0431b3133f4153f215246153f2151b3130c0430c0433f3153f2151b313246150c0431b3133f2150c0431b3133f2150c043246150c0433f2150c043
911400000c0230000300003000030c0230000300003000030c0230000300003000030c0230000300003000030c0230000300003000030c0230000300003000030c0230000300003000030c023000030000300003
51140020021000210002130021250e01002130021200e01502130021200e01002135021200e010021350e01002135021200e01002130021200e01002135021200e01002130021250e010021300e015021330e013
311400001f5351f0261f0201f0101b5351b0261b0201b01016535160161b5351b016145351402614020140101f5351f0261f0201f0101b5351b0261b0201b01016535160161b5351b01614535140261402214011
011400001f7201f0151b7201b015167201601514720140151f7201f0151b7201b0151672016015147201401520720200151b7201b0150c7200c015167201601520720200151b7201b0150c0200c0151602016015
3114000014515140161f5151f0161f0101f0101b5151b0161b0101b01016515160161b5151b016145151401614010140101f5151f0161f0101f0101b5151b0161b0101b01016515160161b5151b0161451514016
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0020000018c5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 15165858
00 15165759
00 15161859
00 15161719
00 15161858
00 15561759
00 55561859
00 55561719
00 15161858
00 15165759
00 15161859
00 15161719
00 15161858
00 15161719
00 15161859
02 15161719

