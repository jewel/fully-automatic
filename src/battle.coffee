canvas = document.getElementById( 'arena' )

ctx = canvas.getContext('2d')

socket = null

last_received = null

timer = false

pos = new Vector( 150, 150 )

bullets = []
others = []
barriers = [
  [
    new Vector( 400, 0 ),
    new Vector( 400, 50 )
  ],
  [
    new Vector( 400, 50 ),
    new Vector( 500, 225 )
  ],
  [
    new Vector( 400, 200 ),
    new Vector( 375, 425 )
  ],
  [
    new Vector( 500, 400 ),
    new Vector( 400, 599 )
  ]
]

reconnect = ->
  socket = io.connect window.location.href

  last_received = new Date().getTime() + 10000

  socket.on 'update', (obj) ->
    last_received = new Date().getTime()
    bullets = []
    others = []
    for b in obj.bullets
      bullets.push
        pos: new Vector(b.pos.x, b.pos.y)
        dir: new Vector(b.dir.x, b.dir.y)

    for o in obj.others
      others.push new Vector( o.x, o.y )

    if obj.hit
      pos = new Vector 100, 100
      velocity = new Vector 0, 0
 
  socket.on 'connect', ->
    last_received = new Date().getTime() + 5000

    if !timer
       window.setInterval get_input, 30

    timer = true

reconnect()

draw = ->
  ctx.save()
  ctx.fillStyle = '#fff'
  ctx.fillRect 0, 0, canvas.width, canvas.height

  ctx.save()
  ctx.lineWidth = 2
  for b in bullets
    ctx.beginPath()
    ctx.moveTo( b.pos.x, b.pos.y )
    end = b.pos.minus b.dir.normalized().mult( 8 )
    ctx.lineTo( end.x, end.y )
    ctx.stroke()
  ctx.restore()

  ctx.beginPath()
  ctx.arc(pos.x, pos.y, 5, 0, Math.PI*2, false)
  ctx.closePath()
  ctx.stroke()
  ctx.fillStyle = '#080'
  ctx.fill()

  for o in others
    ctx.beginPath()
    ctx.arc o.x, o.y, 5, 0, Math.PI*2, false
    ctx.closePath()
    ctx.stroke()
    ctx.fillStyle = '#800'
    ctx.fill()

  for barrier in barriers
    ctx.beginPath()
    for point in barrier
      ctx.lineTo point.x, point.y
    ctx.lineWidth = 4
    ctx.strokeStyle = '#000'
    ctx.stroke()

  for barrier in barriers
    index = 0

    while index < barrier.length - 1
      p1 = barrier[index]
      p2 = barrier[index+1]
      p3 = p1.plus(p1.minus( pos ).times(100))
      p4 = p2.plus(p2.minus( pos ).times(100))
      ctx.beginPath()
      ctx.lineTo( p1.x, p1.y )
      ctx.lineTo( p2.x, p2.y )
      ctx.lineTo( p4.x, p4.y )
      ctx.lineTo( p3.x, p3.y )
      ctx.fillStyle = '#888'
      ctx.fill()
      index++

  ctx.restore()

keys_pressed = {}

mouse_pressed = false

reload = 0

window.onkeydown = (e) ->
  keys_pressed[e.which] = true
  e.which != 32

window.onkeyup = (e) ->
  keys_pressed[e.which] = false
  e.which != 32

window.onmousedown = (e) ->
  mouse_pressed = true

window.onmouseup = (e) ->
  mouse_pressed = false

mouse_position = null

document.onmousemove = (e) ->
  mouse_position = e

velocity = new Vector 0, 0

get_input = ->
  velocity.y -= 0.5   if keys_pressed[87]
  velocity.y += 0.5   if keys_pressed[83]
  velocity.x -= 0.5   if keys_pressed[65]
  velocity.x += 0.5   if keys_pressed[68]
  velocity.mult(0.85) if keys_pressed[32]

  if velocity.length() > 8
    velocity.normalize().mult(8)

  pos.add( velocity )

  if pos.x < 0
     pos.x = 0
     velocity.x = -velocity.x
     velocity.mult(0.75)

  if pos.y < 0
     pos.y = 0
     velocity.y = -velocity.y
     velocity.mult(0.75)

  if pos.x > canvas.width
     pos.x = canvas.width
     velocity.x = -velocity.x
     velocity.mult(0.75)

  if pos.y > canvas.height
     pos.y = canvas.height
     velocity.y = -velocity.y
     velocity.mult(0.75)

  reload-- if reload > 0

  bullet = null

  if mouse_pressed && mouse_position && reload == 0
    dir = new Vector( mouse_position.clientX + window.scrollX - canvas.offsetLeft,
                      mouse_position.clientY + window.scrollY - canvas.offsetTop )
    dir.sub(pos)
    dir.normalize()
    dir.mult( 10 )

    bullet =
      pos: pos.plus(dir)
      dir: dir

    reload = 3

  socket.emit 'update'
    pos: pos
    bullet: bullet

  time_diff = new Date().getTime() - last_received

  if time_diff > 250
    reconnect()

  if time_diff > 30 || time_diff < 0
    for b in bullets
      b.pos.add b.dir

  draw()