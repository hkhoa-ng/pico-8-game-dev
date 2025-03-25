pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- Game engine
screen = "menu"
state = "dropping"
wavy_text_timer = 0

-- Constants
grid = {
    {0,0,0,5,0,0,5},
    {2,0,0,1,0,0,0},
    {0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0},
    {0,0,0,4,0,0,1},
    {0,0,0,2,0,0,0},
    {0,0,0,0,0,0,0},
}
grid_size = 7
tile_size = 12
spr_offset = 5

-- New disc
new_disc = {
    val = 1,
    curr_c = 1,
    to_c = 1,
}
move_speed = 0.05
possible_disc_vals = {-2,1,2,3,4,5,6,7}

-- Dropping disc
drop_discs = {}
gravity = 0.1
found_hanging_discs = false

-- Clearing disc
clear_discs = {}
-- found_discs_to_clear = false
flash_dur = 40  -- number of frames to flash

-- Screenshake
shake = 0 
shake_amp = 3
shake_fade = 0.5

-- Debug
debug1 = #clear_discs
debug2 = state

function _update60()
    if screen == "menu" then
        if (btnp(4) or btnp(5)) then
            screen = "game"
        end
    elseif screen == "game" then
        -- debug1 = #clear_discs
        -- debug2 = state
        screen_shake()
        if state == "control" then
            control()
        elseif state == "dropping" then
            find_hanging_discs()
            dropping_disc()
        elseif state == "clearing" then
            check_clearing()
        end
    elseif screen == "over" then

    end
end

function _draw()
    if screen == "menu" then
        cls(1)
        prinx_wavy_shadow("press ❎  or 🅾️  to start!", 64, 7, 5, 3, 45)
    elseif screen == "game" then
        cls(1)
        -- print(debug1)
        -- print(debug2)
        draw_grid()
        if state == "control" then
            draw_new_disc()
        elseif state == "dropping" then
            draw_drop_discs()
        elseif state == "clearing" then
            flash_n_clear_discs()
        end
    elseif screen == "over" then

    end

end

-->8
-- control & physics
function control()
    -- Move left right & wrap
    if btnp(0) then
        new_disc.to_c -= 1
    elseif btnp(1) then
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
        disc.curr_r = move_towards(disc.curr_r, disc.to_r, gravity)
        if disc.curr_r == disc.to_r then
            if disc.bounces ~= 0 then
                shake = 1
                disc.curr_r = disc.to_r - 0.25 * disc.bounces
                disc.bounces -= 1
            else
                grid[disc.to_r][disc.c] = disc.val
                del(drop_discs, disc)
            end
        end
    end
    if is_empty(drop_discs) then
        state = "clearing"
    end 
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
            for r=grid_size,1,-1 do
                if (grid[r][c] == 0) goto check_clear else rows += 1
            end
            
            -- Clearing discs
            ::check_clear::
            if rows == grid[r][c] or cols == grid[r][c] then
                make_clear_disc(grid[r][c], r, c)
            end
            ::continue::
        end 
    end
    if (#clear_discs == 0) state = "control"
end
-->8
-- draw & animation
function draw_grid()
    for row=1,grid_size do
        gap = row*(tile_size) + tile_size
        length = tile_size*grid_size + tile_size
        line(tile_size, tile_size, length, tile_size, 5)
        line(tile_size, tile_size, tile_size, length, 5)
        line(tile_size, gap, length, gap, 5)
        line(gap, tile_size, gap, length, 5)
        for col=1,grid_size do
            if grid[row][col] ~= 0 then
                print(grid[row][col], col*tile_size+spr_offset, row*tile_size+spr_offset, 7)
            end
        end
    end
end

function draw_new_disc() 
    print(new_disc.val, new_disc.curr_c*tile_size + spr_offset, spr_offset, 14)
end

function draw_drop_discs() 
    for _,disc in pairs(drop_discs) do
        print(disc.val, disc.c*tile_size + spr_offset, disc.curr_r*tile_size + spr_offset, 10)
    end 
end

function flash_n_clear_discs()
    if (#clear_discs == 0) return
    for _,disc in pairs(clear_discs) do
        disc.flash_dur -= 1
        if (disc.flash_dur % 5 == 0) print(disc.val, disc.c*tile_size+spr_offset, disc.r*tile_size+spr_offset, 12)
        if disc.flash_dur == 0 then
            grid[disc.r][disc.c] = 0
            del(clear_discs, disc)
        end
    end

    if #clear_discs == 0 then
        state = "dropping"
        found_hanging_discs = false
    end
end

function screen_shake()
    local shakex = (shake_amp-rnd(shake_amp * 2)) * shake
    local shakey = (shake_amp-rnd(shake_amp * 2)) * shake
    camera(shakex, shakey)
    shake = shake * shake_fade
    if (shake<0.1) shake=0
end
-->8
-- Utils
function prinx(text, y, color)
    print(text,64-#text*2,y,color)
end

function prinx_shadow(text, y, color, shadow)
    local x = 64-#text*2
    for dx=-1,1,2 do
        print(text, x+dx, y, shadow)
        print(text, x, y+dx, shadow)
    end
    prinx(text, y, color)
end

function prinx_wavy_shadow(text, y, color, shadow, amplitude, speed)
    wavy_text_timer = (wavy_text_timer + 1) % 361
    for i=0,#text do
        local x = 64-#text*2 + i*4
        local w = sin((wavy_text_timer+i)/speed)*amplitude
        for dx=-1,1,2 do
            print(sub(text,i,i), x+dx, y+w, shadow)
            print(sub(text,i,i), x, y+w+dx, shadow)
        end
        print(sub(text,i,i), x, y+w, color)
    end
end

function lerp(a, b, t)
    return a + (b - a) * t
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

function is_empty(t)
	for _,_ in pairs(t) do
		return false
	end
	return true
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

__gfx__
00000000000006000666660006666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000066006666006666666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000666006666006666660066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000006666006666006666660066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000066666000000006600000666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700006666000666666000000066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000006666006666000066660066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000006666000666666606666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
