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
    content_type = if path.indexOf(".js") != -1
      'text/javascript'
    else
      'text/html'
    res.writeHead 200
      'Content-Type': content_type
    res.write data, 'utf8'
    res.end()

server.listen 4001

console.log "Server running on http://localhost:4001"

io = io.listen(server)
io.set 'log level', 2

bullets = []
players = {}
hit = {}
last_seen = {}

setInterval( ->
  for b in bullets
    b.pos.add b.dir
    if b.warmup > 0
      b.warmup--
      continue
    for id, p of players
      if p.minus( b.pos ).length_squared() < 25
        hit[id] = true

  new_bullets = []
  for b in bullets
    if b.pos.x < -100 || b.pos.x > 1100 || b.pos.y < -100 || b.pos.y > 700
      continue
    new_bullets.push( b )
  bullets = new_bullets
, 30)

io.sockets.on 'connection', (client) ->
  client.on 'update', (msg) ->
    now = new Date().getTime()
    last_seen[client.id] = now
    if msg.bullet
      bullets.push
        pos: new Vector( msg.bullet.pos.x, msg.bullet.pos.y )
        dir: new Vector( msg.bullet.dir.x, msg.bullet.dir.y )
        warmup: 4

    players[client.id] = new Vector( msg.pos.x, msg.pos.y )
    others = []
    for i, p of players
      if( i == client.id )
        continue
      if( now - last_seen[i] > 500 )
        continue
      others.push p.rounded()

    bulls = []
    for b in bullets
      bulls.push
        pos: b.pos.rounded()
        dir: b.dir.rounded()

    client.emit 'update'
      bullets: bulls,
      others: others,
      hit: hit[client.id]

    delete hit[client.id]

  client.on 'error', ->
    console.log( "error" )

  client.on 'disconnect', ->
    console.log( "disconnect" )
    delete players[client.id]
