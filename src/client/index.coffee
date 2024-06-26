canvas = document.getElementById( 'arena' )

sampleRate = 48000

audioCtx = new AudioContext(sampleRate: sampleRate)

audioBuffers = {}

loadSound = (name) ->
  res = await fetch("/sounds/#{name}.wav")
  arrayBuffer = await res.arrayBuffer()
  audioBuffers[name] = await audioCtx.decodeAudioData arrayBuffer

loadSound 'pew1'
loadSound 'thud1'
loadSound 'boing1'
loadSound 'oof1'
loadSound 'boom1'

activeSounds = []

playSound = (name, source) ->
  return unless audioBuffers[name]
  playBuffer audioBuffers[name], source

voiceTimestamps = {}

# add a buffer for voice track jitter, two frames
# even without network latency, our audio chunks will not come in perfectly
# lined up with our framerate, so some will be delayed

# Two frames seems like a safe amount until we're more sophisticated
audioJitterBuffer = 0.033

playVoice = (voice) ->
  data = new Float32Array voice.data
  audioBuffer = audioCtx.createBuffer 1, data.length, sampleRate
  audioBuffer.copyToChannel data, 0, 0

  nextTime = voiceTimestamps[voice.owner]
  if !nextTime || nextTime < audioCtx.currentTime
    voice.audioStartTime = audioCtx.currentTime + audioJitterBuffer
    voiceTimestamps[voice.owner] = voice.audioStartTime + audioBuffer.duration
  else
    voice.audioStartTime = nextTime
    voiceTimestamps[voice.owner] = nextTime + audioBuffer.duration

  # Changing the playbackRate causes problems because it means if someone is coming towards us that the voice segments will play back faster than real time, which means we'll end up having gaps in them.
  voice.disableDoppler

  playBuffer audioBuffer, voice

playBuffer = (buffer, source) ->
  bufferSource = audioCtx.createBufferSource()
  bufferSource.buffer = buffer

  gainNode = audioCtx.createGain()
  panNode = audioCtx.createStereoPanner()

  bufferSource.connect gainNode
  gainNode.connect panNode
  panNode.connect audioCtx.destination

  sound = {source, bufferSource, gainNode, panNode}

  bufferSource.onended = ->
    index = activeSounds.indexOf sound
    if index > -1
      activeSounds.splice index, 1

  updateSoundNodes sound

  bufferSource.start source.audioStartTime || audioCtx.currentTime
  activeSounds.push sound

simpleSound = (name, gain) ->
  return unless audioBuffers[name]

  bufferSource = audioCtx.createBufferSource()
  bufferSource.buffer = audioBuffers[name]
  gainNode = audioCtx.createGain()
  panNode = audioCtx.createStereoPanner()

  bufferSource.connect gainNode
  gainNode.connect audioCtx.destination
  gainNode.gain.value = gain

  bufferSource.start()


updateSoundNodes = (sound) ->
  source = sound.source
  distance = player.pos.distance source.pos
  # FIXME probably needs to be x^2 in order to sound right
  sourceVolume = 1
  if source.volume?
    sourceVolume = source.volume
  volume = 1 / (1 + distance / 25) * sourceVolume

  pan = (source.pos.x - player.pos.x) / 500
  pan = -1 if pan < -1
  pan = 1 if pan > 1

  sound.gainNode.gain.setValueAtTime volume, audioCtx.currentTime
  sound.panNode.pan.setValueAtTime pan, audioCtx.currentTime

  if source.disableDoppler
    playbackRate = 1
  else
    relativeVelocity = source.dir.minus player.dir
    direction = source.pos.minus player.pos
    dotProduct = relativeVelocity.dot direction
    directionMagnitude = direction.length()
    if directionMagnitude != 0
      relativeSpeed = dotProduct / directionMagnitude
    else
      relativeSpeed = 0

    speedOfSound = 343
    playbackRate = 1 + relativeSpeed / speedOfSound

  sound.bufferSource.playbackRate.setValueAtTime playbackRate, audioCtx.currentTime

viewScale = 1

draw = ->
  # temporary empty draw function for first call to onResize

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

identity = localStorage.getItem("identity")
if !identity
  identity = Math.random().toString()
  localStorage.setItem "identity", identity

player = null
facing = new Vector 0, 0
map = null
bullets = []
others = []
bases = []
currentTick = 0

serverVersion = null

moveToSpawn = ->
  player.pos = Vector.load(map.spawns[player.team]).plus new Vector(randomInt(50) - 25, randomInt(50) - 25)
  player.dir = new Vector 0, 0

each_barrier_segment = (callback) ->
  for barrier in map.barriers
    index = 0
    points = barrier.points
    while index < points.length - 1
      callback barrier, points[index], points[index+1]
      index++

connect = ->
  socket = io.connect window.location.href

  # socket.io.engine.on 'packet', ({type, data}) ->
  #   if type == 'message'
  #     console.log data if data.indexOf('update') == -1

  socket.on 'version', (version) ->
    if !serverVersion
      serverVersion = version
    else if serverVersion != version
      location.reload()

  socket.on 'map', (obj) ->
    map = obj.map
    for barrier in map.barriers
      newPoints = []
      for p in barrier.points
        newPoints.push Vector.load p
      barrier.points = newPoints

  socket.on 'player', (obj) ->
    if player?
      # server reset during development, ignore
    else
      player = obj.player
      # we must have refreshed, trust the server position
      if player.pos?
        player.pos = Vector.load player.pos
        player.dir = new Vector 0, 0
      else
        moveToSpawn()

  socket.on 'update', (msg) ->
    # We can measure lag easily here because this update message is in direct
    # response to ours
    currentTick = msg.tick
    others = msg.others
    for o in others
      o.pos = Vector.load o.pos

    bases = msg.bases
    for b in bases
      b.pos = Vector.load b.pos

    for e in msg.events
      [tick, type, obj] = e

      switch type
        when 'bullet'
          obj.pos = Vector.load obj.pos
          obj.dir = Vector.load obj.dir

          bullets.push obj
          if obj.owner == identity
            obj.volume = 0.3
          playSound "pew1", obj

        when 'boing'
          obj.pos = Vector.load obj.pos
          obj.dir = new Vector 0, 0
          playSound "boing1", obj

        when 'death'
          obj.pos = Vector.load obj.pos
          obj.dir = new Vector 0, 0
          playSound "oof1", obj

        when 'base_hit'
          obj.pos = Vector.load obj.pos
          obj.dir = new Vector 0, 0
          playSound "boom1", obj

        when 'voice'
          obj.pos = Vector.load obj.pos
          obj.dir = new Vector 0, 0
          continue if obj.owner == identity
          playVoice obj

        else
          console.log 'unknown event type: #{type}'

  socket.on 'connect', ->
    socket.emit 'identity', {identity}

  socket.io.on 'reconnect', ->
    socket.emit 'identity', {identity}

connect()

px = (x) -> (x - player.pos.x) * viewScale + canvas.width / 2
py = (y) -> (y - player.pos.y) * viewScale + canvas.height / 2

draw = ->
  return unless player

  ctx.save()
  # blank canvas
  ctx.fillStyle = '#888'
  ctx.fillRect 0, 0, canvas.width, canvas.height

  # draw inside map
  ctx.fillStyle = '#fff'
  ctx.fillRect px(0), py(0), map.width * viewScale, map.height * viewScale

  # draw bullets
  ctx.lineWidth = 2 * viewScale
  for b in bullets
    ctx.beginPath()
    ctx.moveTo( px(b.pos.x), py(b.pos.y) )
    end = b.pos.minus b.dir.normalized().mult( 8 )
    ctx.lineTo( px(end.x), py(end.y) )
    if b.team == player.team
      ctx.strokeStyle = '#aaa'
    else
      ctx.strokeStyle = '#000'
    ctx.stroke()

  # draw bases
  for base in bases
    ctx.beginPath()
    if base.team == 1
      ctx.arc(px(base.pos.x), py(base.pos.y), base.health * viewScale, 0, Math.PI / 2, false)
    else
      ctx.arc(px(base.pos.x), py(base.pos.y), base.health * viewScale, Math.PI, Math.PI * 3 / 2, false)
    ctx.lineTo px(base.pos.x), py(base.pos.y)
    ctx.closePath()
    ctx.stroke()
    if base.team == 1
      ctx.fillStyle = "#f00"
    else
      ctx.fillStyle = "#00f"
    ctx.fill()

  # draw players
  ctx.beginPath()
  ctx.arc(px(player.pos.x), py(player.pos.y), 5 * viewScale, 0, Math.PI*2, false)
  ctx.closePath()
  ctx.lineWidth = 1
  ctx.strokeStyle = '#000'
  ctx.stroke()
  if player.team == 1
    ctx.fillStyle = "#f00"
  else
    ctx.fillStyle = "#00f"
  ctx.fill()

  ctx.beginPath()
  darknessPoint = player.pos.minus facing.times(20)
  darknessPoint2 = darknessPoint.plus(new Vector(facing.y, -facing.x).times(1000))
  darknessPoint3 = darknessPoint.plus(new Vector(-facing.y, facing.x).times(1000))
  darknessPoint4 = darknessPoint.minus(facing.times(1000))
  ctx.lineTo px(darknessPoint2.x), py(darknessPoint2.y)
  ctx.lineTo px(darknessPoint4.x), py(darknessPoint4.y)
  ctx.lineTo px(darknessPoint3.x), py(darknessPoint3.y)
  ctx.closePath()
  ctx.fillStyle = "#ccc"
  ctx.fill()

  for o in others
    ctx.beginPath()
    ctx.arc px(o.pos.x), py(o.pos.y), 5 * viewScale, 0, Math.PI*2, false
    ctx.closePath()
    ctx.stroke()
    if o.team == 1
      ctx.fillStyle = "#800"
    else
      ctx.fillStyle = "#008"
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

  ctx.restore()

keys_pressed = {}

mouse_pressed = false

reload = 0

recording = false

constraints =
  audio:
    sampleRate: sampleRate
    channelCount: 1

microphoneStream = null

recordingStarted = false
startRecording = ->
  return if recordingStarted
  navigator.mediaDevices.getUserMedia(constraints).then (stream) ->
    microphoneStream = stream

    return unless microphoneStream
    audioCtx.resume().then ->
      source = audioCtx.createMediaStreamSource microphoneStream
      processor = audioCtx.createScriptProcessor 1024, 1, 1

      processor.onaudioprocess = (e) ->
        return unless recording
        audioData = e.inputBuffer.getChannelData 0
        return if audioData.length == 0
        socket.emit 'voice', audioData

      source.connect processor

      # Chrome does not bother with the script processor unless it is connected to
      # the destination
      processor.connect audioCtx.destination

      recordingStarted = true

document.onkeydown = (e) ->
  return unless player
  keys_pressed[e.which] = true
  if e.key == ' '
    recording = true
    startRecording()
  ( e.which < 37 || e.which > 40 )

fullscreen = false

document.onkeyup = (e) ->
  return unless player
  if e.key == ' '
    recording = false
  if e.key == 'f'
    if fullscreen
      canvas.releasePointerCapture e.pointerId
      document.exitFullscreen()
    else
      canvas.setPointerCapture e.pointerId
      # Setting the canvas as fullscreen means that there will be padding added to the element where our black body normally is
      document.body.requestFullscreen()

    fullscreen = !fullscreen
    return
  keys_pressed[e.which] = false
  ( e.which < 37 || e.which > 40 )

document.onmousedown = (e) ->
  mouse_pressed = true
  false

document.onmouseup = (e) ->
  mouse_pressed = false
  false

mouse_pos = null

document.onmousemove = (e) ->
  mouse_pos = e

  rect = canvas.getBoundingClientRect()
  mouseX = mouse_pos.clientX - rect.left
  mouseY = mouse_pos.clientY - rect.top

  facing = new Vector mouseX, mouseY
  facing.sub x: canvas.width / 2, y: canvas.height / 2
  facing.normalize()
  facing.mult 5

randomInt = (max) ->
  Math.floor Math.random() * max

getInput = ->
  return unless player

  acc = 0.25
  player.dir.y -= acc if keys_pressed[87] || keys_pressed[38]
  player.dir.y += acc if keys_pressed[83] || keys_pressed[40]
  player.dir.x -= acc if keys_pressed[65] || keys_pressed[37]
  player.dir.x += acc if keys_pressed[68] || keys_pressed[39]
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

    socket.emit 'boing',
      pos: player.pos
      volume: player.dir.length() / 4 # divide by max speed

    delta = a.minus b
    normal = new Vector( delta.y, -delta.x ).normalize()
    player.dir = normal.times( -2 * player.dir.dot( normal ) ).plus(player.dir)
    player.dir.mult 0.75
    player.pos = closest.plus(  player.pos.minus(closest).normalize().times(7) )


  reload-- if reload > 0

  bullet = null

  if mouse_pressed && mouse_pos && reload == 0
    rect = canvas.getBoundingClientRect()
    mouseX = mouse_pos.clientX - rect.left
    mouseY = mouse_pos.clientY - rect.top

    dir = new Vector mouseX, mouseY
    dir.sub x: canvas.width / 2, y: canvas.height / 2
    dir.normalize()
    dir.mult 5

    bullet =
      pos: player.pos.plus(dir)
      dir: dir
      team: player.team
      owner: identity

    # Figure out which wall bullet will hit
    minTime = Infinity
    minBarrier = null

    each_barrier_segment (barrier, p1, p2) ->
      maxDistance = map.width + map.height
      bulletEnd = bullet.pos.plus(bullet.dir.normalized().times(maxDistance))
      intersection = Vector.intersection bullet.pos, bulletEnd, p1, p2
      return unless intersection

      # calculate intersect time
      diff = intersection.minus bullet.pos
      if dir.x != 0
        t = diff.x / dir.x
      else if dir.y != 0
        t = diff.y / dir.y
      else
        t = 0

      if t < minTime
        minTime = t
        minBarrier = barrier

    if minTime < Infinity
      bullet.deathTick = currentTick + Math.round(minTime)
    else
      bullet = null

    # shoot faster in own base
    if minBarrier && minBarrier.team != player.team
      reload = 8
    else
      reload = 6

  socket.emit 'update',
    pos: player.pos
    bullet: bullet
    name: name

  for b in bullets
    b.pos.add b.dir

  # see if bullet hit us
  for b in bullets
    continue if b.team == player.team
    distanceToFront = b.pos.distance(player.pos)
    continue if distanceToFront > 8 + 10
    end = b.pos.minus b.dir.normalized().mult( 8 )
    distanceToEnd = b.pos.distance(player.pos)
    if distanceToFront <= 5 || distanceToEnd <= 5
      socket.emit 'death',
        pos: player.pos

      moveToSpawn()

  # see if our own bullets hit enemy base
  for bullet in bullets
    continue unless bullet.owner == identity
    continue if bullet.spent
    for base in bases
      continue if base.team == bullet.team
      distance = base.pos.distance bullet.pos
      if distance < base.health
        bullet.spent = true
        socket.emit 'base_hit',
          pos: bullet.pos
          team: base.team

  # Clean out old bullets
  newBullets = []
  for bullet in bullets
    if bullet.deathTick <= currentTick
      playSound "thud1", bullet
      continue

    newBullets.push bullet
  bullets = newBullets

  currentTick++

  for sound in activeSounds
    updateSoundNodes sound

  draw()

setInterval getInput, 1000/60
