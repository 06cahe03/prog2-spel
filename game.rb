require "gosu"
require "opengl"

class Game < Gosu::Window
  def initialize
    GL.load_lib
    super(800, 600)
    self.caption ="gaming"
    @start = Time.now.to_f

    @grab = Grabbable.new("media/img/carrot.png", 20, 100)
    @font = Gosu::Font.new(24)

    @grabbed = false
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
  end
  
  def draw
    @grab.draw
    #@test.draw(@test_x, @test_y, 0)
    #@font.draw_text("#{@test_x},#{@test_y} #{@test_x + @test.width},#{@test_y + @test.height}\n#{self.mouse_x},#{self.mouse_y} #{Gosu.button_down?(Gosu::MS_LEFT)}\n#{((@test_x + @test.width / 2) - self.mouse_x).abs}", 10, 10, 0)
  end
end

class Sprite
  def initialize(path, x = 0, y = 0)
    @obj = Gosu::Image.new(path)
    @x = x
    @y = y
  end

  def update
  end

  def draw
    @obj.draw(@x, @y)
  end

  def hitbox?(x, y)
    half_w = @obj.width / 2
    half_h = @obj.height / 2

    off_x = ((@x + half_w) - x).abs
    off_y = ((@y + half_h) - y).abs

    off_x < half_w && off_y < half_h
  end
end

class Grabbable < Sprite
  attr_writer :grabbed
  
  def initialize(path, x = 0, y = 0)
    super(path, x, y)
    @grabbed = false
  end

  def update(x, y, w, h)
    if @grabbed
      @x = (x - @obj.width / 2).clamp(0, w - @obj.width)
      @y = (y - @obj.height / 2).clamp(0, h - @obj.height)
    end
  end

  def try_grab(x, y)
    if hitbox?(x, y)
      @grabbed = true
    end
  end
end

Game.new.show
