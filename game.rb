require "gosu"
require "opengl"

def check_pixel(lines, x, y, dir)
  if lines[y][x] == 255
    # find connecting, anything outside counts as black
    sides = {
      "l" => (x - 1) >= 0 && lines[y][x - 1] == 255,
      "r" => (x + 1) < 50 && lines[y][x + 1] == 255,
      "u" => (y - 1) >= 0 && lines[y - 1][x] == 255,
      "d" => (y + 1) < 40 && lines[y + 1][x] == 255
    }
    sides.delete(dir) # very optimized
    # check if only one side is true
    if sides.select {|_, v| v}.length == 1
      return sides.key(true)
    end
  end
end

def generate_path(pix)
  # key: the direction we are going
  # val: x, y, direction we came from
  lookup = {
    "l" => [-1,  0, "r"],
    "r" => [ 1,  0, "l"],
    "u" => [ 0, -1, "d"],
    "d" => [ 0,  1, "u"]
  }

  # grab R value from RGBA data and sort into lines
  i = 0
  lines = []
  pix.bytes.each_slice(4) do |x|
    if lines[i].nil?
      lines[i] = []
    end
    lines[i].push(x[0])
    if lines[i].length >= 50
      i += 1
    end
  end

  path = []
  dir = "u" # which direction to ignore, aka where we came from

  # find "entry" pixel from the top
  # start of line MUST go down from the top
  # TODO: assert for invalid maps
  x = lines[0].each_index do |x|
    # check connecting pixels
    # pretend we came from the top
    brr = check_pixel(lines, x, 0, "u")
    if !brr.nil?
      path.push([x, 0])
      break x
    end
  end

  # begin loop at next line
  y = 1
  while true do
    # push current point
    path.push([x, y])
    # check connecting pixels
    brr = check_pixel(lines, x, y, dir)
    # if there are none we probably reached the end
    if brr.nil?
      break
    end
    # update current state
    x += lookup[brr][0]
    y += lookup[brr][1]
    dir = lookup[brr][2]
  end

  p path
  return path
end

class Game < Gosu::Window
  def initialize
    GL.load_lib
    super(1280, 800)
    self.caption ="gaming"

    @background = Gosu::Image.new("media/img/crude_map_pathTEST.png", {
      :retro => true
    })
    @test_path = generate_path(@background.to_blob)

    @grab = Grabbable.new("media/img/carrot.png", 20, 100, @test_path)
    @font = Gosu::Font.new(24)

    @tenemy = Sprite.new("media/img/carrot.png", @test_path[0][0] * 20, @test_path[0][1] * 20)
    @tenemy_i = 0
    @tenemy_last = 0
  end

  def button_down(btn)
    if btn == Gosu::MS_LEFT
      @grab.try_grab(mouse_x, mouse_y)
    end
  end

  def button_up(btn)
    if btn == Gosu::MS_LEFT
      @grab.grabbed = false
    end
  end

  def update
    @grab.update(mouse_x, mouse_y, width, height)

    # temp test
    if Gosu.milliseconds - @tenemy_last > 500
      @tenemy_last = Gosu.milliseconds
      @tenemy_i += 1
      if @tenemy_i >= @test_path.length
        @tenemy_i = 0
      end
      @tenemy.x = @test_path[@tenemy_i][0] * 20
      @tenemy.y = @test_path[@tenemy_i][1] * 20
    end
  end
  
  def draw
    @background.draw(0, 0, 0, 20, 20)
    @grab.draw
    Gosu.draw_rect(1280-280, 0, 280, 800, Gosu::Color::GRAY)

    # temp test
    @test_path.each do |point|
      Gosu.draw_rect(point[0] * 20, point[1] * 20, 15, 15, Gosu::Color::YELLOW)
    end
    @tenemy.draw
    #@test.draw(@test_x, @test_y, 0)
    #@font.draw_text("#{@test_x},#{@test_y} #{@test_x + @test.width},#{@test_y + @test.height}\n#{self.mouse_x},#{self.mouse_y} #{Gosu.button_down?(Gosu::MS_LEFT)}\n#{((@test_x + @test.width / 2) - self.mouse_x).abs}", 10, 10, 0)
  end
end

class Sprite
  attr_writer :x, :y

  def initialize(path, x = 0, y = 0)
    @obj = Gosu::Image.new(path)
    @x = x
    @y = y
  end

  def update
  end

  def draw
    @obj.draw(@x, @y, 10)
  end

  # basic square hitbox
  def hitbox?(x, y)
    x >= @x && x - @x < @obj.width && y >= @y && y - @y < @obj.height
  end
end

class Grabbable < Sprite
  attr_writer :grabbed
  
  def initialize(path, x = 0, y = 0, temp_path)
    super(path, x, y)
    @grabbed = false
    @temp_path = temp_path
  end

  def update(x, y, w, h)
    if @grabbed
      @x = (x - @obj.width / 2).clamp(0, w - @obj.width)
      @y = (y - @obj.height / 2).clamp(0, h - @obj.height)
    end
  end

  def draw
    super
    if @grabbed
      color = Gosu::Color::GREEN
      # TEMP
      # TODO: this is terrible
      @temp_path.each do |point|
        if hitbox?(point[0] * 20, point[1] * 20)
          color = Gosu::Color::RED
          break
        end
      end
      Gosu.draw_rect(@x - 10, @y - 10, @obj.width + 20, @obj.height + 20, color)
    end
  end

  def try_grab(x, y)
    if hitbox?(x, y)
      @grabbed = true
    end
  end
end

Game.new.show
