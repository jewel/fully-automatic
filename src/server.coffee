http = require 'http'
url = require 'url'
fs = require 'fs'
io = require 'socket.io'
sys = require 'sys'
{Vector} = require './vector'

send404 = (res) ->
  res.writeHead(404)
  res.write('404')
  res.end()
  res

server = http.createServer (req,res) ->
  path = url.parse(req.url).pathname
  console.log( path )
  path = '/index.html' if path == '/'
  fs.readFile "#{__dirname}/../public/" + path, (err,data) ->
    return send404 res if err
    ext = path.substr path.lastIndexOf( "." ) + 1
    content_type = switch ext
      when 'js' then 'text/javascript'
      when 'css' then 'text/css'
      when 'html' then 'text/html'
      else
        console.log "Unknown content type: #{ext}"
    res.writeHead 200
      'Content-Type': content_type
    res.write data, 'utf8'
    res.end()

server.listen 4000

console.log "Server running on http://localhost:4000"

io = io.listen(server)
io.set 'log level', 2

bullets = []
barriers = [
  [
    new Vector( 400, 0 ),
    new Vector( 400, 50 )
    new Vector( 500, 225 )
  ],
  [
    new Vector( 400, 200 ),
    new Vector( 375, 425 )
  ],
  [
    new Vector( 500, 400 ),
    new Vector( 400, 599 )
  ],
  [
    new Vector( 800, 250 ),
    new Vector( 810, 375 ),
    new Vector( 860, 385 )
  ]
]

each_barrier_segment = (callback) ->
  for b in barriers
    index = 0
    while index < b.length - 1
      callback( b[index], b[index+1] )
      index++

players = {}
hit = {}
last_seen = {}
scores = {}
names = {}
scoreboard = []
colors = {}

color_choices = [ '080', '800', '008', '880', '808', '088', '888' ]
color_index = 0

setInterval( ->
  for b in bullets
    b.pos.add b.dir
    if b.warmup > 0
      b.warmup--
      continue
    for id, p of players
      if p.minus( b.pos ).length_squared() < 25
        scores[id]++ unless hit[id]
        hit[id] = true

  scoreboard = []
  for id, name of names
    scoreboard.push
      name: name
      value: scores[id]
      color: colors[id]

  new_bullets = []
  for b in bullets
    if b.pos.x < -100 || b.pos.x > 1100 || b.pos.y < -100 || b.pos.y > 700
      continue

    destroyed = false

    each_barrier_segment (p1,p2) ->
      closest = b.pos.intersection( p1, p2 )
      return unless closest
      return if b.pos.distance( closest ) > 7
      destroyed = true

    continue if destroyed

    new_bullets.push( b )
  bullets = new_bullets
, 30)

io.sockets.on 'connection', (client) ->
  colors[client.id] = color_choices[ color_index++ % color_choices.length ]
  console.log colors
  client.on 'update', (msg) ->
    now = new Date().getTime()
    last_seen[client.id] = now
    if msg.bullet
      bullets.push
        pos: new Vector( msg.bullet.pos.x, msg.bullet.pos.y )
        dir: new Vector( msg.bullet.dir.x, msg.bullet.dir.y )
        warmup: 4

    names[client.id] = msg.name
    scores[client.id] = 0 unless scores[client.id]
    players[client.id] = new Vector( msg.pos.x, msg.pos.y )
    others = []
    for i, p of players
      if( i == client.id )
        continue
      if( now - last_seen[i] > 500 )
        continue
      others.push
        pos: p.rounded()
        color: colors[i]

    bulls = []
    for b in bullets
      bulls.push
        pos: b.pos.rounded()
        dir: b.dir.rounded()

    client.emit 'update'
      bullets: bulls
      others: others
      barriers: barriers
      hit: hit[client.id]
      scores: scoreboard
      color: colors[client.id]

    delete hit[client.id]

  client.on 'error', ->
    console.log( "error" )

  client.on 'disconnect', ->
    console.log( "disconnect" )
    delete players[client.id]
    delete scores[client.id]
    delete names[client.id]
