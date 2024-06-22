class Vector
  constructor: (@x, @y) ->

  @load: (obj) ->
    new Vector obj.x, obj.y

  # Find the intersection of line segments P1-P2 and P3-P4
  @intersection: (p1, p2, p3, p4) ->
    s1 = p2.minus p1
    s2 = p4.minus p3

    s = (-s1.y * (p1.x - p3.x) + s1.x * (p1.y - p3.y)) / (-s2.x * s1.y + s1.x * s2.y)
    t = ( s2.x * (p1.y - p3.y) - s2.y * (p1.x - p3.x)) / (-s2.x * s1.y + s1.x * s2.y)

    if s >= 0 && s <= 1 && t >= 0 && t <= 1
      new Vector p1.x + (t * s1.x), p1.y + (t * s1.y)
    else
      null

  equals: (other) ->
    @x == other.x && @y == other.y

  rounded: ->
    new @constructor Math.round( @x ), Math.round( @y )

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

  times_vector: (other) ->
    new @constructor( @x * other.x, @y * other.y )

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

  distance: (other) ->
    Math.sqrt (@x - other.x) * (@x - other.x) +
              (@y - other.y) * (@y - other.y)

  # Find closest point on line segment AB to this point
  closest: (a,b) ->
    len = a.distance b
    return @distance(a) if len == 0
    t = @minus(a).dot( b.minus( a ) ) / ( len * len )
    return null if t < 0 || t > 1
    a.plus( b.minus( a ).times( t ) )


root = exports ? this
root.Vector = Vector
