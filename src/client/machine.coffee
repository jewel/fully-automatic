# This is a state machine that will run a simulation on each of the connected
# machines, including the server.  This avoids the need to communicate any
# information about bullets that are traveling through the air (as there will
# be thousands of them at any given time).
#
# Walls are part of the machine, as bullets that hit them will automatically be
# destroyed.  Since a player cannot stop a bullet, we can compute the full path
# of the bullets as soon as they are added to the machine and remove them once
# they reach the wall.
#
# Players are not part of the machine.  Players compute their own collisions.
#
# We'll store the bullets in such a way that they can be injected after-the-fact
# without impacting the computation of the state machine.
class Machine
  constructor: (world) ->
    @world = world
    @wipe()

  wipe: ->
    @bullets = []

  add: (start_tick, start_position, direction) ->
    # calculate the wall collision
    [end_position, end_tick] = world.collide position, direction

    # since bullets cannot interact with each other, it does not matter if they
    # are added in the same order on each client
    @bullets.push {start_tick, end_tick, start_position, direction}

  advance: ->
    # This is almost a no-op, as we can compute the current position of each
    # bullet each frame.  We just need to clean up bullets that are no longer
    # useful.
    @bullets = @bullets.filter (bullet) ->
       bullet.end_tick >= @world.tick

  bullets: ->
    @bullets
