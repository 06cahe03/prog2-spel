require "gosu"

class PathGenerator
  attr_reader :path

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
    return result
  end

  def find_entry()
    (0..50).each do |x|
      # check connecting pixels pretending we came from the top
      arr = find_connecting(x, 0, :u)
      # find pixel with ONE connecting
      if arr.length == 1
        # add to path and return
        @path << {
          :x => x * 20 + 10, # screenspace middle
          :y => 10
        }
        return x
      end
    end
    return nil
  end

  def initialize(source)
    # create and export rgba data from file
    rgba = Gosu::Image.new(source).to_blob

    # verify image size
    raise ArgumentError, "path image must be 50x40 pixels (RGBA)" if rgba.length != 50 * 40 * 4

    # grab R value from RGBA data and sort into lines
    pixels = rgba.bytes.each_slice(4)
    @lines = Array.new(40) {Array.new(50) {pixels.next[0]}}
    @path = []

    # find "entry" pixel from the top
    # start of line MUST go down from the top
    x = find_entry()
    raise ArgumentError, "no entry found in path" if x.nil?

    y = 1 # begin loop at next line
    dir = :u # which direction to ignore, aka where we came from

    while true do
      # push current point
      @path << {
        :x => x * 20 + 10, # screenspace middle
        :y => y * 20 + 10
      }

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
    @font = Gosu::Font.new(24)

    # import background and generate path
    @background = Gosu::Image.new("media/img/map_test3.png")
    @test_path = PathGenerator.new("media/img/path_test3.png")

    # store all objects and grabbed object
    @sprites = []
    @grabbed = nil

    # TEMP TEST ENEMY
    @test_enemy = Sprite.new("media/img/carrot.png", @test_path.path[0][:x], @test_path.path[0][:y])
    @test_enemy_i = 0
    @test_enemy_last = 0
    @sprites << @test_enemy

    # TEMP TEST GRAB
    test_grab = Grabbable.new("media/img/carrot.png", 20, 100)
    @sprites << test_grab

    # TEMP TEST inverted grab
    bleh = test_grab.to_blob
    out = []
    bleh.bytes.each_slice(4) do |rgba|
      out << 255 - rgba[0]
      out << 255 - rgba[1]
      out << 255 - rgba[2]
      out << rgba[3]
    end
    test_grab2 = Grabbable.from_blob(test_grab.width, test_grab.height, out.pack("C*"))
    test_grab2.move(20, 200)
    @sprites << test_grab2
  end

  def update
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
      point = @test_path.path[@test_enemy_i % @test_path.path.length]
      @test_enemy.move(point[:x], point[:y])
    end
  end
  
  def draw
    @background.draw(0, 0)

    # draw with rendering order (later elements draw on top)
    @sprites.each_with_index {|x, i| x.draw(i + 10)}

    # placeholder for right side menu
    Gosu.draw_rect(1000, 0, 280, 800, Gosu::Color::GRAY)

    # TEMP GRAB TEST
    if !@grabbed.nil?
      color = Gosu::Color::GREEN
      # TODO: this is terrible
      @test_path.path.each do |point|
        if @grabbed[:s].hitbox?(point[:x], point[:y], 25)
          color = Gosu::Color::RED
          break
        end
      end
      Gosu.draw_rect(@grabbed[:s].x - 10, @grabbed[:s].y - 10, @grabbed[:s].width + 20, @grabbed[:s].height + 20, color, 7)
      #Gosu.draw_rect(@grabbed[:s].x, @grabbed[:s].y, @grabbed[:s].width, @grabbed[:s].height, Gosu::Color::GRAY, 8)
    end

    # TEMP ENEMY TEST
    if @debug
      #@font.draw_text("#{@grabbed[:s] || "nil"}", 10, 10, 0)
      @test_path.path.each do |point|
        Gosu.draw_rect(point[:x] - 25, point[:y] - 25, 50, 50, Gosu::Color::FUCHSIA, 5)
        Gosu.draw_rect(point[:x] - 10, point[:y] - 10, 20, 20, Gosu::Color::BLUE, 6)
        Gosu.draw_rect(point[:x], point[:y], 1, 1, Gosu::Color::YELLOW, 7)
      end
    end
  end

  def button_down(btn)
    case btn
    when Gosu::MS_LEFT
      # try grab ONE grabbable
      @sprites.select {|s| s.grabbable }.each do |s|
        # check hitbox for sprite
        if s.hitbox?(mouse_x, mouse_y)
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
        @test_path.path.each do |point|
          if @grabbed[:s].hitbox?(point[:x], point[:y], 25)
            # illegal! return to sender
            @grabbed[:s].move(@grabbed[:x], @grabbed[:y])
            break
          end
        end
        # remove anything grabbed
        @grabbed = nil
      end
    end
  end
end

class Sprite < Gosu::Image
  attr_reader :x, :y

  def initialize(source, x = 0, y = 0)
    super(source)
    move(x, y)
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

  # basic square hitbox with expansion (how much extra around to check)
  def hitbox?(x, y, e = 0)
    x + e >= @x && x - @x < width + e && y + e >= @y && y - @y < height + e
  end

  # not sketchy at all
  def grabbable
    false
  end
end

class Grabbable < Sprite
  def grabbable
    true
  end
end

Game.new.show
