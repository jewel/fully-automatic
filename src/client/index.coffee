canvas = document.getElementById( 'arena' )

viewScale = 1

draw = ->

onResize = ->
  w = window.innerWidth
  h = window.innerHeight
  ml = 0
  mt = 0
  if w / h > 16 / 9
    w = h * 16 / 9
    ml = (window.innerWidth - w) / 2
  else
    h = w * 9 / 16
    mt = (window.innerHeight - h) / 2
  canvas.width = w
  canvas.height = h
  canvas.style.marginTop = "#{Math.floor(mt)}px"
  canvas.style.marginLeft = "#{Math.floor(ml)}px"
  viewScale = h / 1080
  draw()

onResize()

window.addEventListener 'resize', onResize

ctx = canvas.getContext('2d')

socket = null

last_received = null

identity = localStorage.getItem "identity"
if !identity
  identity = Math.random()
  localStorage.setItem "identity", identity
console.log "i am #{identity}"

timer = false

player = null
map = null
bullets = []
others = []
bases = null
currentTick = 0

each_barrier_segment = (callback) ->
  for barrier in map.barriers
    index = 0
    points = barrier.points
    while index < points.length - 1
      callback barrier, points[index], points[index+1]
      index++

reconnect = ->
  socket = io.connect window.location.href

  last_received = new Date().getTime() + 10000

  socket.on 'map', (obj) ->
    map = obj.map
    for barrier in map.barriers
      newPoints = []
      for p in barrier.points
        newPoints.push Vector.load p
      barrier.points = newPoints

  socket.on 'player', (obj) ->
    player = obj.player
    player.pos = Vector.load player.pos
    player.dir = Vector.load player.dir

  socket.on 'update', (obj) ->
    last_received = new Date().getTime()
    currentTick = obj.tick
    others = obj.others
    for o in others
      o.pos = Vector.load o.pos

    for b in obj.bullets
      b.pos = Vector.load b.pos
      b.dir = Vector.load b.dir

      bullets.push b

  socket.on 'connect', ->
    last_received = new Date().getTime() + 5000

    socket.emit 'identity', {identity}

    if !timer
       window.setInterval get_input, 1000/60

    timer = true

reconnect()

px = (x) -> (x - player.pos.x) * viewScale + canvas.width / 2
py = (y) -> (y - player.pos.y) * viewScale + canvas.height / 2

draw = ->
  ctx.save()
  ctx.fillStyle = '#888'
  ctx.fillRect 0, 0, canvas.width, canvas.height
  ctx.fillStyle = '#fff'
  ctx.fillRect px(0), py(0), map.width * viewScale, map.height * viewScale

  ctx.save()
  ctx.lineWidth = 2 * viewScale
  for b in bullets
    ctx.beginPath()
    ctx.moveTo( px(b.pos.x), py(b.pos.y) )
    end = b.pos.minus b.dir.normalized().mult( 8 )
    ctx.lineTo( px(end.x), py(end.y) )
    ctx.stroke()

    for i in b.intersections
      ctx.beginPath()
      ctx.arc(px(i.x), py(i.y), 5 * viewScale, 0, Math.PI*2, false)
      ctx.closePath()
      ctx.fillStyle = "#000"
      ctx.fill()

  ctx.restore()

  ctx.beginPath()
  ctx.arc(px(player.pos.x), py(player.pos.y), 5 * viewScale, 0, Math.PI*2, false)
  ctx.closePath()
  ctx.stroke()
  if player.team == 1
    ctx.fillStyle = "#f00"
  else
    ctx.fillStyle = "#00f"
  ctx.fill()


  for o in others
    ctx.beginPath()
    ctx.arc px(o.pos.x), py(o.pos.y), 5 * viewScale, 0, Math.PI*2, false
    ctx.closePath()
    ctx.stroke()
    if o.team == 1
      ctx.fillStyle = "#800"
    else
      ctx.fillStyle == "#008"
    ctx.fill()

  each_barrier_segment ( barrier, p1, p2 ) ->
    return if barrier.edge
    p3 = p1.plus p1.minus( player.pos ).times(1000)
    p4 = p2.plus p2.minus( player.pos ).times(1000)
    ctx.beginPath()
    ctx.lineTo px(p1.x), py(p1.y)
    ctx.lineTo px(p2.x), py(p2.y)
    ctx.lineTo px(p4.x), py(p4.y)
    ctx.lineTo px(p3.x), py(p3.y)
    ctx.lineTo px(p1.x), py(p1.y)
    ctx.fillStyle = '#888'

    ctx.fill()
    ctx.strokeStyle = '#888'
    ctx.lineWidth = 4 * viewScale
    ctx.lineCap = 'round'
    ctx.lineJoin = 'round'
    ctx.stroke()

  for barrier in map.barriers
    ctx.beginPath()
    for point in barrier.points
      ctx.lineTo px(point.x), py(point.y)
    ctx.lineWidth = 4 * viewScale
    if barrier.team == 1
      ctx.strokeStyle = '#844'
    else
      ctx.strokeStyle = '#448'
    ctx.stroke()

  for b in bullets
    for i in b.intersections
      ctx.beginPath()
      ctx.arc(px(i.x), py(i.y), 5 * viewScale, 0, Math.PI*2, false)
      ctx.closePath()
      ctx.fillStyle = "#000"
      ctx.fill()

  ctx.restore()

keys_pressed = {}

mouse_pressed = false

reload = 0

window.onkeydown = (e) ->
  return unless player
  keys_pressed[e.which] = true
  e.which != 32 && ( e.which < 37 || e.which > 40 )

fullscreen = false

window.onkeyup = (e) ->
  return unless player
  if e.key == 'f'
    if fullscreen
      canvas.exitFullscreen()
    else
      canvas.requestFullscreen()
    fullscreen = !fullscreen
    return
  keys_pressed[e.which] = false
  e.which != 32 && ( e.which < 37 || e.which > 40 )

window.onmousedown = (e) ->
  mouse_pressed = true
  false

window.onmouseup = (e) ->
  mouse_pressed = false
  false

mouse_pos = null

document.onmousemove = (e) ->
  mouse_pos = e

get_input = ->
  return unless player

  acc = 0.25
  player.dir.y -= acc if keys_pressed[87] || keys_pressed[38]
  player.dir.y += acc if keys_pressed[83] || keys_pressed[40]
  player.dir.x -= acc if keys_pressed[65] || keys_pressed[37]
  player.dir.x += acc if keys_pressed[68] || keys_pressed[39]
  player.dir.mult 0.925 if keys_pressed[32]
  player.dir.mult 0.925 unless keys_pressed[87] ||
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

  if player.dir.length() > max_speed
    player.dir.mult 0.925

  player.pos.add player.dir

  # Bounce off walls
  each_barrier_segment (barrier, a, b) ->
    closest = player.pos.closest( a, b )
    return unless closest
    return if player.pos.distance( closest ) > 6
    # http://www.yaldex.com/games-programming/0672323699_ch13lev1sec5.html
    delta = a.minus b
    normal = new Vector( delta.y, -delta.x ).normalize()
    player.dir = normal.times( -2 * player.dir.dot( normal ) ).plus(player.dir)
    player.dir.mult 0.75
    player.pos = closest.plus(  player.pos.minus(closest).normalize().times(7) )


  reload-- if reload > 0

  bullet = null

  if mouse_pressed && mouse_pos && reload == 0
    # FIXME account for viewScale
    dir = new Vector( mouse_pos.clientX + window.scrollX - canvas.offsetLeft,
                      mouse_pos.clientY + window.scrollY - canvas.offsetTop )
    dir.sub {x: canvas.width / 2, y: canvas.height / 2}
    dir.normalize()
    dir.mult 5

    bullet =
      pos: player.pos.plus(dir)
      dir: dir

    # Figure out which wall bullet will hit
    minTime = Infinity
    intersections = []
    each_barrier_segment (barrier, p1, p2) ->
      maxDistance = map.width + map.height
      bulletEnd = bullet.pos.plus(bullet.dir.normalized().times(maxDistance))
      intersection = Vector.intersection bullet.pos, bulletEnd, p1, p2
      return unless intersection
      intersections.push intersection

      # calculate intersect time
      diff = intersection.minus bullet.pos
      if dir.x != 0
        t = diff.x / dir.x
      else if dir.y != 0
        t = diff.y / dir.y
      else
        t = 0
      minTime = Math.min minTime, t

    if minTime < Infinity
      bullet.deathTick = currentTick + Math.round(minTime)
      bullet.intersections = intersections
    else
      bullet = null

    reload = 6

  socket.emit 'update',
    pos: player.pos
    bullet: bullet
    name: name

  # time_diff = new Date().getTime() - last_received

  # if time_diff > 2000
  #   reconnect()

  for b in bullets
    b.pos.add b.dir

  newBullets = []

  # Clean out old bullets
  bullets = bullets.filter (b) ->
    b.deathTick >= currentTick

  currentTick++

  draw()
