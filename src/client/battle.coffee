canvas = document.getElementById( 'arena' )

ctx = canvas.getContext('2d')

socket = null

last_received = null

name = "Nobody"

color = "000"

timer = false

pos = new Vector 25, 25
velocity = new Vector 0, 0

map_width = 5000
map_height = 5000

bullets = []
others = []
barriers = []

each_barrier_segment = (callback) ->
  for b in barriers
    index = 0
    while index < b.length - 1
      callback( b[index], b[index+1] )
      index++

reconnect = ->
  socket = io.connect window.location.href

  last_received = new Date().getTime() + 10000

  socket.on 'update', (obj) ->
    last_received = new Date().getTime()
    bullets = []
    others = []
    barriers = []
    color = obj.color

    for b in obj.bullets
      bullets.push
        pos: new Vector(b.pos.x, b.pos.y)
        dir: new Vector(b.dir.x, b.dir.y)

    for o in obj.others
      others.push
        pos: new Vector( o.pos.x, o.pos.y )
        color: o.color

    for b in obj.barriers
      barrier = []
      for p in b
        barrier.push new Vector( p.x, p.y )
      barriers.push barrier

    random_int = (max) ->
      Math.round( Math.random() * max )

    if obj.hit
      pos = new Vector random_int(map_width), random_int(map_height)
      velocity = new Vector 0, 0

  socket.on 'connect', ->
    last_received = new Date().getTime() + 5000

    if !timer
       window.setInterval get_input, 1000/60

    timer = true

reconnect()

px = (x) -> x - pos.x + canvas.width / 2
py = (y) -> y - pos.y + canvas.height / 2

draw = ->
  ctx.save()
  ctx.fillStyle = '#888'
  ctx.fillRect 0, 0, canvas.width, canvas.height
  ctx.fillStyle = '#fff'
  ctx.fillRect px(0), py(0), map_width, map_height

  ctx.save()
  ctx.lineWidth = 2
  for b in bullets
    ctx.beginPath()
    ctx.moveTo( px(b.pos.x), py(b.pos.y) )
    end = b.pos.minus b.dir.normalized().mult( 8 )
    ctx.lineTo( px(end.x), py(end.y) )
    ctx.stroke()
  ctx.restore()

  ctx.beginPath()
  ctx.arc(px(pos.x), py(pos.y), 5, 0, Math.PI*2, false)
  ctx.closePath()
  ctx.stroke()
  ctx.fillStyle = "##{color}"
  ctx.fill()


  for o in others
    ctx.beginPath()
    ctx.arc px(o.pos.x), py(o.pos.y), 5, 0, Math.PI*2, false
    ctx.closePath()
    ctx.stroke()
    ctx.fillStyle = "##{o.color}"
    ctx.fill()

  each_barrier_segment ( p1, p2 ) ->
    p3 = p1.plus p1.minus( pos ).times(1000)
    p4 = p2.plus p2.minus( pos ).times(1000)
    ctx.beginPath()
    ctx.lineTo px(p1.x), py(p1.y)
    ctx.lineTo px(p2.x), py(p2.y)
    ctx.lineTo px(p4.x), py(p4.y)
    ctx.lineTo px(p3.x), py(p3.y)
    ctx.lineTo px(p1.x), py(p1.y)
    ctx.fillStyle = '#888'
    ctx.fill()
    ctx.strokeStyle = '#888'
    ctx.lineWidth = 4
    ctx.lineCap = 'round'
    ctx.lineJoin = 'round'
    ctx.stroke()

  for barrier in barriers
    ctx.beginPath()
    for point in barrier
      ctx.lineTo px(point.x), py(point.y)
    ctx.lineWidth = 4
    ctx.strokeStyle = '#666'
    ctx.stroke()


  ctx.restore()

keys_pressed = {}

mouse_pressed = false

reload = 0

window.onkeydown = (e) ->
  keys_pressed[e.which] = true
  e.which != 32 && ( e.which < 37 || e.which > 40 )

window.onkeyup = (e) ->
  keys_pressed[e.which] = false
  e.which != 32 && ( e.which < 37 || e.which > 40 )

window.onmousedown = (e) ->
  mouse_pressed = true
  false

window.onmouseup = (e) ->
  mouse_pressed = false
  false

mouse_position = null

document.onmousemove = (e) ->
  mouse_position = e

get_input = ->
  acc = 0.25
  velocity.y -= acc if keys_pressed[87] || keys_pressed[38]
  velocity.y += acc if keys_pressed[83] || keys_pressed[40]
  velocity.x -= acc if keys_pressed[65] || keys_pressed[37]
  velocity.x += acc if keys_pressed[68] || keys_pressed[39]
  velocity.mult(0.925) if keys_pressed[32]
  velocity.mult(0.925) unless keys_pressed[87] ||
                              keys_pressed[83] ||
                              keys_pressed[65] ||
                              keys_pressed[68] ||
                              keys_pressed[38] ||
                              keys_pressed[40] ||
                              keys_pressed[37] ||
                              keys_pressed[39]

  if reload
    max_speed = 2
  else
    max_speed = 4

  if velocity.length() > max_speed
    velocity.mult(0.925)

  pos.add( velocity )

  if pos.x < 0
     pos.x = 0
     velocity.x = -velocity.x
     velocity.mult(0.875)

  if pos.y < 0
     pos.y = 0
     velocity.y = -velocity.y
     velocity.mult(0.875)

  if pos.x > map_width
     pos.x = map_width
     velocity.x = -velocity.x
     velocity.mult(0.875)

  if pos.y > map_height
     pos.y = map_height
     velocity.y = -velocity.y
     velocity.mult(0.875)

  each_barrier_segment (a, b) ->
    closest = pos.intersection( a, b )
    return unless closest
    return if pos.distance( closest ) > 6
    # http://www.yaldex.com/games-programming/0672323699_ch13lev1sec5.html
    delta = a.minus b
    normal = new Vector( delta.y, -delta.x ).normalize()
    velocity = normal.times( -2 * velocity.dot( normal ) ).plus(velocity)
    velocity.mult 0.75
    pos = closest.plus(  pos.minus(closest).normalize().times(7) )


  reload-- if reload > 0

  bullet = null

  if mouse_pressed && mouse_position && reload == 0
    dir = new Vector( mouse_position.clientX + window.scrollX - canvas.offsetLeft,
                      mouse_position.clientY + window.scrollY - canvas.offsetTop )
    dir.sub {x: canvas.width / 2, y: canvas.height / 2}
    dir.normalize()
    dir.mult 5

    bullet =
      pos: pos.plus(dir)
      dir: dir

    reload = 6

  socket.emit 'update',
    pos: pos
    bullet: bullet
    name: name

  time_diff = new Date().getTime() - last_received

  if time_diff > 250
    reconnect()

  if time_diff > 30 || time_diff < 0
    for b in bullets
      b.pos.add b.dir

  draw()
