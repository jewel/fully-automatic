class Vector
  constructor: (@x, @y) ->

  equals: (other) ->
    @x == other.x && @y == other.y

  rounded: ->
    new Vector Math.round( @x ), Math.round( @y )

  plus: (other) ->
    new @constructor( @x + other.x, @y + other.y )

  add: (other) ->
    @x += other.x
    @y += other.y
    this

  minus: (other) ->
    new @constructor( @x - other.x, @y - other.y )

  sub: (other) ->
    @x -= other.x
    @y -= other.y
    this

  times: (scalar) ->
    new @constructor( @x * scalar, @y * scalar )

  mult: (scalar) ->
    @x *= scalar
    @y *= scalar
    this

  clone: ->
    new @constructor( @x, @y )

  length: ->
    Math.sqrt( @length_squared() )

  length_squared: ->
    @x * @x + @y * @y

  normalize: ->
    len = @length()

    if Math.abs(len) < 0.00001
      @x = 0
      @y = 0
      return this

    @x /= len
    @y /= len
    this

  normalized: ->
    @clone().normalize()

  dot: (other) ->
    @x * other.x + @y * other.y

root = exports ? this
root.Vector = Vector
