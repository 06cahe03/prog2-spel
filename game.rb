require "gosu"

class Point
  attr_reader :x, :y

  def initialize(x, y)
    @x = x
    @y = y
  end

  def collide_box
    [@x, @y, 25, 25]
  end
end

class PathGenerator < Array
  # key: the direction we are going
  # val: x, y, direction we came from
  LOOKUP = {
    :l => [-1,  0, :r],
    :r => [ 1,  0, :l],
    :u => [ 0, -1, :d],
    :d => [ 0,  1, :u]
  }

  def find_connecting(x, y, dir)
    result = []
    if @lines[y][x] == 255
      # find connecting, anything outside counts as black
      sides = {
        :l => (x - 1) >= 0 && @lines[y][x - 1] == 255,
        :r => (x + 1) < 50 && @lines[y][x + 1] == 255,
        :u => (y - 1) >= 0 && @lines[y - 1][x] == 255,
        :d => (y + 1) < 40 && @lines[y + 1][x] == 255
      }
      # filter truthy sides where we didnt come from
      result = sides.select {|k, v| k != dir && v}.keys
    end
    result
  end

  def find_entry()
    (0..50).each do |x|
      # check connecting pixels pretending we came from the top
      arr = find_connecting(x, 0, :u)
      # find pixel with ONE connecting
      if arr.length == 1
        # add to path and return
        self << Point.new(x * 20 + 10, 10) # screenspace middle
        return x
      end
    end
    nil
  end

  def initialize(source)
    super()

    # create and export rgba data from file
    rgba = Gosu::Image.new(source).to_blob

    # verify image size
    raise ArgumentError, "path image must be 50x40 pixels (RGBA)" if rgba.length != 50 * 40 * 4

    # grab R value from RGBA data and sort into lines
    pixels = rgba.bytes.each_slice(4)
    @lines = Array.new(40) {Array.new(50) {pixels.next[0]}}

    # find "entry" pixel from the top
    # start of line MUST go down from the top
    x = find_entry()
    raise ArgumentError, "no entry found in path" if x.nil?

    y = 1 # begin loop at next line
    dir = :u # which direction to ignore, aka where we came from

    while true do
      # push current point
      self << Point.new(x * 20 + 10, y * 20 + 10) # screenspace middle

      # check connecting pixels
      arr = find_connecting(x, y, dir)
      res = case arr.length
      # none means we probably reached the end
      when 0 then break
      # three means a crossing, so we just continue the same direction
      when 3 then LOOKUP[dir][2]
      # otherwise there should only be one
      else arr[0]
      end

      # update current state
      x += LOOKUP[res][0]
      y += LOOKUP[res][1]
      dir = LOOKUP[res][2]
    end
  end

  private :find_entry, :find_connecting
end

class Game < Gosu::Window
  def initialize
    super(1280, 800)
    self.caption ="gaming"

    # debug stuff
    @debug = true
    @font = Gosu::Font.new(32, { :name => "Comic Sans MS" })

    # import background and generate path
    @background = Gosu::Image.new("media/img/map_test3.png")
    @path = PathGenerator.new("media/img/path_test3.png")

    # custom cursor
    @cursor = Cursor.new

    # store all objects and grabbed object
    @sprites = []
    @grabbed = nil

    # TEMP TEST ENEMY
    @test_enemy = Sprite.new("media/img/carrot.png", @path[0].x, @path[0].y)
    @test_enemy_i = 0
    @test_enemy_last = 0
    @sprites << @test_enemy

    # TEMP TEST store
    @money = 69
    test_shop_back = Sprite.new("media/img/store_background.png", 1000, 0)
    @sprites << test_shop_back

    # TEMP TEST grab shop buy thing
    test_shop = Buyable.new("media/img/carrot.png", 1100, 100)
    @sprites << test_shop
  end

  def needs_cursor?
    false
  end

  def update
    # move cursor pos
    if mouse_x > 0 && mouse_y > 0
      @cursor.move(mouse_x, mouse_y)
    end
    
    # exec update on all sprites
    @sprites.each {|s| s.update}

    # move grabbed item if exist
    if !@grabbed.nil?
      @grabbed[:s].move(
        (mouse_x - @grabbed[:s].width / 2).clamp(0, width - @grabbed[:s].width),
        (mouse_y - @grabbed[:s].height / 2).clamp(0, height - @grabbed[:s].height)
      )
    end

    # TEMP ENEMY TEST
    if Gosu.milliseconds - @test_enemy_last > 500
      @test_enemy_last = Gosu.milliseconds
      @test_enemy_i += 1
      point = @path[@test_enemy_i % @path.length]
      @test_enemy.move(point.x, point.y)
    end
  end
  
  def draw
    @background.draw(0, 0)
    @cursor.draw(10000)

    # draw with rendering order (later elements draw on top)
    @sprites.each_with_index {|x, i| x.draw(i + 10)}

    # TEMP GRAB TEST
    if !@grabbed.nil?
      color = Gosu::Color::GREEN
      if collision(@grabbed[:s])
        color = Gosu::Color::RED
      end
      Gosu.draw_rect(
        @grabbed[:s].x - 10,
        @grabbed[:s].y - 10,
        @grabbed[:s].width + 20,
        @grabbed[:s].height + 20,
        color,
        @sprites.length - 2 + 10 # render under grabbed object (which is last)
      )
    end

    # TEMP TEST shop
    @font.draw_text("$#{@money}", 1050, 750, 100)

    # TEMP ENEMY TEST
    if @debug
      #@font.draw_text("#{@grabbed[:s] || "nil"}", 10, 10, 0)
      @path.each do |point|
        Gosu.draw_rect(point.x - 25, point.y - 25, 50, 50, Gosu::Color::FUCHSIA, 5)
        Gosu.draw_rect(point.x - 10, point.y - 10, 20, 20, Gosu::Color::BLUE, 6)
        Gosu.draw_rect(point.x, point.y, 1, 1, Gosu::Color::YELLOW, 7)
      end
    end
  end

  def button_down(btn)
    case btn
    when Gosu::MS_LEFT
      # try grab ONE grabbable
      @sprites.each do |s|
        # check hitbox for sprite
        if s.grabbable && s.hitbox?(mouse_x, mouse_y, 0, 0)
          # duplicate if store item
          if s.buyable
            s = s.clone
            # very optimized
            @sprites << s
          end

          # update state
          @grabbed = {
            :s => s,
            :x => s.x,
            :y => s.y
          }

          # update rendering order
          s = @sprites.delete(s)
          @sprites << s

          break
        end
      end
    end
  end

  def button_up(btn)
    case btn
    when Gosu::KB_Z then @debug = !@debug
    when Gosu::MS_LEFT
      if !@grabbed.nil?
        # check if legal dropping point
        if collision(@grabbed[:s])
          # illegal! return to sender
          @grabbed[:s].move(@grabbed[:x], @grabbed[:y])
        end

        # remove anything grabbed
        @grabbed = nil
      end
    end
  end

  def collision(target)
    # check for both path points and sprites
    @path.chain(@sprites).each do |p|
      # ignore myself
      if target != p && target.hitbox?(*p.collide_box)
        return true
      end
    end
    false
  end
end

class Sprite < Gosu::Image
  attr_reader :x, :y

  def initialize(source, x = 0, y = 0)
    super(source)
    move(x, y)
  end

  # common interface defs
  def grabbable
    false
  end
  def buyable
    false
  end

  # dummy update function called from game
  def update
  end

  # draw function called from game
  def draw(z)
    super(@x, @y, z)
  end

  # lets the game move sprite for grabbing etc
  def move(x, y)
    @x = x
    @y = y
  end

  # "advanced" square hitbox
  def hitbox?(x, y, sx, sy)
    x + sx >= @x && x < @x + width + sx && y + sy >= @y && y < @y + height + sy
  end

  def collide_box
    [@x + width / 2, @y + height / 2, width / 2, height / 2]
  end
end

class Cursor < Sprite
  NORMAL = "media/img/cursor_normal.png"
  CLICK = "media/img/cursor_click.png"

  def initialize
    super(NORMAL, 0, 0)
  end

  def normal
    insert(NORMAL, 0, 0)
  end

  def click
    insert(CLICK, 0, 0)
  end
end

class Grabbable < Sprite
  def grabbable
    true
  end
end

class Buyable < Grabbable
  def initialize(source, x, y)
    super(source, x, y)
    @source = source
  end

  def buyable
    true
  end

  def clone
    Grabbable.new(@source, @x, @y)
  end
end

Game.new.show
