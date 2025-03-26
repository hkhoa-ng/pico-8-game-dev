pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- Game engine
screen = "over"
state = "dropping"
wavy_text_timer = 0
difficulties = {"hard", "normal", "easy"} 
diff = 3
diff_col = 0    -- color for difficulty


-- Constants
grid = {
    {0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0},
    {0,0,0,5,0,0,0},
    {0,0,0,4,0,0,0},
    {0,0,0,2,0,0,0},
    {0,0,0,1,0,0,0},
}
grid_size = 7
tile_size = 12
line_length = tile_size * (grid_size + 1)
grid_offset = 64 - line_length/2 - tile_size/2
grid_top_offset = 16
spr_offset = 2
null_block = -10

-- New disc
new_disc = {
    val = 1,
    curr_c = 1,
    to_c = 1,
}
move_speed = 0.02
possible_disc_vals = {-2,1,2,3,4,5,6,7}
new_disc_bounce_timer = 0
new_disc_bounce_amp = 2
new_disc_bounce_speed = 60
new_disc_top_offset = 2

-- Rising row
drops_for_new_row = 7
drops_counter = 0

-- Dropping disc
drop_discs = {}
gravity = 0.07
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
score_delay = 30 -- delay before actually deduct the score
floating_txts = {}
combo_box_w = 20
combo_box_h = 10
combo_box_offset_y = 10
combo_box_offset_x = 8

-- Particles
smokes = {}
new_bg_line_timer = 0
trails = {}
score_buffer = 0

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
debug1 = #clear_discs
debug2 = state

function _init()
    for r=1,grid_size do
        for c=1,grid_size do
            grid[r][c] = 0
        end
    end
    new_disc.val = rnd(possible_disc_vals)
end

function _update60()
    new_bg_line_timer = (new_bg_line_timer + 1) % 361
    if (new_bg_line_timer % 30 == 0) make_bg_lines()
    if screen == "menu" then
        if (btnp(0)) diff += 1
        if (btnp(1)) diff -= 1
        if (diff > 3) diff = 1
        if (diff < 1) diff = 3
        if (btnp(4) or btnp(5)) then
            screen = "game"
            drops_for_new_row = 1 * diff
        end
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
        if (btnp(4) or btnp(5)) then
            screen = "menu"
            _init()
        end
    end
end

function _draw()
    cls()
    draw_bg_lines()
    if screen == "menu" then
        draw_menu()
    elseif screen == "game" then
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
    elseif screen == "over" then
        local score_string = "score: "..tostr(score)
        local x = 59-#score_string/2*4
        prinx_drop_shadow("game over!", 52, 7, 1)
        prinx_wavy_shadow(score_string, x, 65, diff_col, 1, 2, 45)
        prinx_drop_shadow("press ❎ or 🅾️ to start!", 100, 7, 1)
    end

end

-->8
-- control & physics
function control()
    -- Reset combo
    -- combo = 0
    -- Move left right & wrap
    if btnp(0) then
        -- sfx(0)
        new_disc.to_c -= 1
    elseif btnp(1) then
        -- sfx(0)
        new_disc.to_c += 1
    end
    if new_disc.to_c < 1 then new_disc.to_c = 7 end
    if new_disc.to_c > 7 then new_disc.to_c = 1 end

    -- Smooth movement
    new_disc.curr_c = move_towards(new_disc.curr_c, new_disc.to_c, move_speed*2)

    -- Dropping
    if btnp(4) and new_disc.curr_c == new_disc.to_c then
        -- Find the highest avalailable space under the new disc
        for r=grid_size,1,-1 do
            if grid[r][new_disc.curr_c] == 0 then
                make_drop_disc(new_disc.val, 0, r, new_disc.curr_c)
                new_disc.val = rnd(possible_disc_vals)
                break
            end
        end
        state = "dropping"
        found_hanging_discs = false
        drops_counter += 1
    end
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
                shake = 1
                -- sfx(1)
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
            screen = "over"
            return
        end
    end
    -- Move all other rows up 1
    for c=1,grid_size do
        for r=2,grid_size do
            -- grid[r-1][c] = grid[r][c]
            make_drop_disc(grid[r][c], r, r-1, c)
            -- grid[r][c] = 0
        end
        -- New gray row at bottom
        make_drop_disc(-2, 8, 7, c)
        -- grid[7][c] = -2
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
        end
    end
    -- Check right
    if (c < grid_size and grid[r][c+1] < 0) then
        grid[r][c+1] += 1
        if (grid[r][c+1] == 0) then
            grid[r][c+1] = rnd(possible_disc_vals)
            make_smoke((c+1)*(tile_size+0.5)+grid_offset+2*spr_offset, (r+0.5)*tile_size+grid_offset+grid_top_offset, 6)
        end
    end
    -- Check up
    if (r > 1 and grid[r-1][c] < 0) then
        grid[r-1][c] += 1
        if (grid[r-1][c] == 0) then
            grid[r-1][c] = rnd(possible_disc_vals)
            make_smoke((c)*(tile_size+0.5)+grid_offset+2*spr_offset, (r-0.5)*tile_size+grid_offset+grid_top_offset, 6)
        end
    end
    -- Check down
    if (r < grid_size and grid[r+1][c] < 0) then
        grid[r+1][c] += 1
        if (grid[r+1][c] == 0) then
            grid[r+1][c] = rnd(possible_disc_vals)
            make_smoke((c)*(tile_size+0.5)+grid_offset+2*spr_offset, (r+1.5)*tile_size+grid_offset+grid_top_offset, 6)
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
function draw_menu()
    local x, y, scale = 18, 15, 3
    for i=0,15 do
        pal(i, 1)
    end
    sspr(0, 16, 32, 24, x + wiggle(wavy_text_timer, 3, 90), y+scale, 32*scale, 24*scale)
    pal()
    sspr(0, 16, 32, 24, x + wiggle(wavy_text_timer, 3, 90), y, 32*scale, 24*scale)
    local diff_name = difficulties[diff]
    local diff_x = 42
    if (diff_name == "easy") then
        diff_col = 12
        diff_x = 42
    end
    if (diff_name == "normal") then
        diff_col =  9
        diff_x = 38
    end
    if (diff_name == "hard") then
        diff_col = 8
        diff_x = 42
    end
    prinx_wavy_shadow("⬅️  "..difficulties[diff].." ➡️", diff_x, 87, diff_col, 1, 2, 45)
    prinx_drop_shadow("press ❎ or 🅾️ to start!", 100, 7, 1)
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
    print_drop_shadow("x", 96, 13, 8, 1)

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
        linger = 60 -- number of frames to linger after reaching
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
000000000000030007aaaa000aaaaa00eeee00e27eeeeee80777cc10994444420077770000777700000000000000000000000000000000000000000000000000
00000000000073007aa900a9a9999994e88200e27ee800007cccccc19440044207ddddd007000060000000000000000000000000000000000000000000000000
007007000007b300aaa900a9a9940094e88200e207eeee807cc10000000044207dddddd5700dd005000000000000000000000000000000000000000000000000
00077000007bb300999900a944440094e88200e2000000e87cc10000000942007dddddd570dddd05000000000000000000000000000000000000000000000000
0007700007bbb300000000a900000494e88200e27ee800e87ccccc10000942007dddddd570ddd505000000000000000000000000000000000000000000000000
0070070000bbb300077aaa9000000094022888827ee800e8ccc100c1000942007dddddd5700d5005000000000000000000000000000000000000000000000000
0000000000bbb3007aa90000aa990094000000e27ee800e8ccc100c1000942000ddddd5006000050000000000000000000000000000000000000000000000000
00000000003333000999999904444440000000e20888888001cccc10000942000055550000555500000000000000000000000000000000000000000000000000
00000000000000000000000000001000000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000011000000330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000011000000330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000011111110333333300011000000330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000111111103333333000011000000330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000011000000330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000011000000330000000000000000000000000000001110222333444000000000000000000000000000000000000000000000000
00000000000000000000000000010000000300000000000000000000000000000001110222333444000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000001110222333444000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000005556660008880000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000005556667778880000000000000000000000000000000000000000000000000
000000000bb000000000000000000000000000000000000000000000000000000005556667778880000000000000000000000000000000000000000000000000
00000000b00b00000000000000cccc0000000000000000000000000000000000009999aaabbbccc0000000000000000000000000000000000000000000000000
00000000b00000000000000ccc000c0000000000000000000000000000000000009999aaabbbccc0600000000000000000000000000000000000000000000000
00000000b0000000000000c00000c00000000000000000000000000000000000009999eeebbbccc0000000000000000000000000000000000000000000000000
00000000b0000000000000c00000c00000000000000000000000000000000000000dddeee0fff000000000000000000000000000000000000000000000000000
0000000b0000000000000000000cc00000000000000000000000000000000000000dddeee0fff000000000000000000000000000000000000000000000000000
0000000b0000000000000000000c000000000000000000000000000000000000000ddd0000fff000000000000000000000000000000000000000000000000000
0000000b000aaa0000000000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000bbb000a00099000088000cc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000b00b0aa000990900880800c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b000b00a000900908800800c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b000b00a000900900800800c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b000b000a00909900808800c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000bbb0b00a00099000888000c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111e1e111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111e1e111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111eee111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111e111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111e111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
70000000077077707070777000007700777007707770777000007770770007700000011111111111111111111111111111111111111111111111111111111111
07000000700070707070700000007070707070707070007000007070707070000000055555555555555555555555555551111111111111111111111111111111
00700000777077707070770000007070770070707770007000007770707070000000011151111111111151111111111151111111111111111111111111111111
07000000007070707770700000007070707070707000007000007000707070700000011151111111111151111111111151111111111111111111111111111111
70000000770070700700777000007770707077007000007007007000707077700000011151111111111151111111111151111111111111111111111111111111
00000000000000000000000000000000000000000000000000000000000000000000011151111111111151111111111151111111111111111111111111111111
90909990999099009990990009900000000090009990999099909000000099900990000099909000999099009090000000000000000000000000000000000000
90909090909090900900909090000900000090009090909090009000000009009000000090909000909090909090000000000000000000000000000000000000
90909990990090900900909090000000000090009990990099009000000009009990000099009000999090909900000000000000000000000000000000000000
99909090909090900900909090900900000090009090909090009000000009000090000090909000909090909090000000000000000000000000000000000000
99909090909090909990909099900000000099909090999099909990000099909900000099909990909090909090000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
aaa0a0a0aa0000000aa0aaa0aaa0aaa00000aaa0aa00aa0000000aa0aaa0aaa0a0000000aaa00000aaa00aa000000aa0aaa0aaa0aaa0a0a0aaa0aaa000000000
a0a0a0a0a0a00000a000a0a0a0a00a000000a0a0a0a0a0a00000a0000a00a0a0a000000000a000000a00a0a00000a000a0a0a0a00a00a0a0a0a0a00000000000
aa00a0a0a0a00000a000aaa0aa000a000000aaa0a0a0a0a00000a0000a00aa00a000aaa000a000000a00a0a00000a000aaa0aaa00a00a0a0aa00aa0000000000
a0a0a0a0a0a00000a000a0a0a0a00a000000a0a0a0a0a0a00000a0000a00a0a0a000000000a000000a00a0a00000a000a0a0a0000a00a0a0a0a0a00000000000
a0a00aa0a0a000000aa0a0a0a0a00a000000a0a0a0a0aaa000000aa00a00a0a0aaa0000000a000000a00aa0000000aa0a0a0a0000a000aa0a0a0aaa000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06606660606066606600000066006660066066606660000066606660000066606600066000000000000000000000000000000000000000000000000000000000
60006060606060006060000060606060606060600060000060606060000060606060600000000000000000000000000000000000000000000000000000000000
66606660606066006060000060606600606066600060000066606660000066606060600000000000000000000000000000000000000000000000000000000000
00606060666060006060000060606060606060000060000060006060000060006060606000000000000000000000000000000000000000000000000000000000
66006060060066606660000066606060660060000060060060006660060060006060666000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000000001111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
07000000000005555555555555555555555555555555555555555555555555555555555555555555555555555555555551111111111111111111111111111111
00700000000001111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
07000000000001111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
70000000000001111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
00000000000001111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111155555555555555555555555555555555555555555555555555555555555555555555555555555555555551111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111771111151111771111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111171111151111171111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111171111151111171111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111171111151111171111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111777111151111777111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111155555555555555555555555555555555555555555555555555555555555555555555555555555555555551111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111777111151111111111151111111111151111111111151111771111151111111177751111111177151111111111111111111111111111111
11111111111151111711111151111111111151111111111151111111111151111171111151111111111751111111117151111111111111111111111111111111
11111111111151111777111151111111111151111111111151111111111151111171111151111777177751111777117151111111111111111111111111111111
11111111111151111117111151111111111151111111111151111111111151111171111151111111171151111111117151111111111111111111111111111111
11111111111151111777111151111111111151111111111151111111111151111777111151111111177751111111177751111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111155555555555555555555555555555555555555555555555555555555555555555555555555555555555551111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111711111151111711111151111111111151111711111151111111177151111111177751111111177751111111111111111111111111111111
11111111111151111711111151111711111151111111111151111711111151111111117151111111111751111111111751111111111111111111111111111111
11111111111151111777111151111777111151111111111151111777111151111777117151111777177751111777177751111111111111111111111111111111
11111111111151111717111151111717111151111111111151111717111151111111117151111111171151111111171151111111111111111111111111111111
11111111111151111777111151111777111151111111111151111777111151111111177751111111177751111111177751111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111155555555555555555555555555555555555555555555555555555555555555555555555555555555555551111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111177751111111177151111777111151111111177151111111177751111111177751111111177751111111111111111111111111111111
11111111111151111111111751111111117151111117111151111111117151111111111751111111111751111111111751111111111111111111111111111111
11111111111151111777177751111777117151111177111151111777117151111777177751111777177751111777177751111111111111111111111111111111
11111111111151111111171151111111117151111117111151111111117151111111171151111111171151111111171151111111111111111111111111111111
11111111111151111111177751111111177751111777111151111111177751111111177751111111177751111111177751111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111151111111111111111111111111111111
11111111111155555555555555555555555555555555555555555555555555555555555555555555555555555555555551111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
eee11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
e1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
eee11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11e11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
eee11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111

__sfx__
0006000000120021300313001120001100011000100001002100015100250001710002000240001a1001d100300002110023100000000000027100360002a1002b1002d1002e1003010032100331000000000000
000600000f5700c5600a5400753003510005000050001500057000570000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00030000250502b050240502605028050290502a0502b0502c0502d0502e0502f0503005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
