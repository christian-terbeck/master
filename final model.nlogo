globals [time mean-speed stddev-speed flow-cum overall-contacts overall-contact-time unique-contacts critical-contacts contact-distance-values contact-distance]

breed [peds ped]
peds-own [speedx speedy state final-destination next-destination has-reached-first-node? starting-point last-node all-paths shortest-path has-created-circle?
          number-of-unique-contacts number-of-contacts had-contact-with active-contacts active-contacts-periods]

breed [nodes node]
nodes-own [reachable-nodes is-origin? is-destination? has-public-display?]

breed [circles circle]

to setup
  clear-all
  reset-ticks

  import-pcolors "floorplans/example.png"

  set-default-shape circles "circle 2"

  set-nodes
  set-agents

  ask peds [
    if show-circles? and not has-created-circle? [
      create-circle
      set has-created-circle? true
    ]
  ]

  if show-logs? [
    print "--- NEW SIMULATION ---"
  ]
end

to create-circle
  hatch-circles 1 [
    set size contact-radius
    set color lput 20 extract-rgb color
    __set-line-thickness 0.5

    create-link-with myself [
      tie
      hide-link
    ]
  ]
end

to set-nodes
  create-node -10 -2 false false    ; 0
  create-node 16 -2 false false     ; 1
  create-node 12 -6 false false     ; 2
  create-node 13 -12 true false     ; 3
  create-node 0 -2 false false      ; 4
  create-node -10 -10 false true    ; 5
  create-node 13 13 false true      ; 6
  create-node -13 13 false true     ; 7
  create-node 0 13 false true       ; 8
  create-node 0 -13 false true      ; 9
  create-node -18 15 false true     ; 10
  create-node -18 -2 false true     ; 11
  create-node -18 -15 false true    ; 12
  create-node 8 17.5 false true     ; 13

  ;Todo: use netlogo links for decision points instead!
  establish-connection node 0 node 7
  establish-connection node 0 node 4
  establish-connection node 0 node 5
  establish-connection node 4 node 9
  establish-connection node 4 node 8
  establish-connection node 4 node 2
  establish-connection node 4 node 1
  establish-connection node 9 node 2
  establish-connection node 9 node 3
  establish-connection node 2 node 1
  establish-connection node 2 node 3
  establish-connection node 1 node 6
  establish-connection node 6 node 8


  establish-connection node 10 node 7
  establish-connection node 11 node 0
  establish-connection node 12 node 5
  establish-connection node 13 node 8
  establish-connection node 13 node 6
end

to set-agents
  repeat nb-peds [create-ped 0 0 0]
  ask n-of round (p * nb-peds) peds [set state 2 set color orange]
end

to create-ped  [x y k]
  let randfour random 4
  ;if k = 0 [ask one-of patches with [not any? peds-here and pcolor = white] [set x pxcor set y pycor]]
  let s-point nobody
  if k = 0 [ask one-of nodes with [is-destination? = false] [set x pxcor set y pycor set s-point self]]
  create-peds 1 [
    set shape "person"
    set color cyan
    set xcor x + random-normal 0 .2
    set ycor y + random-normal 0 .2
    set final-destination one-of nodes with [is-destination? = true]
    set next-destination nobody
    set has-reached-first-node? false
    set starting-point s-point
    set last-node s-point
    set all-paths []
    set shortest-path [] set-initial-path-and-next-destination k
    set has-created-circle? false
    set had-contact-with []
    set active-contacts []
    set active-contacts-periods []
    face node 1

    if k = -1 [set color green set state -1]
  ]
end

to create-node [x y dest origin]
  create-nodes 1 [ set xcor x set ycor y set reachable-nodes [] set is-destination? dest set shape "circle" ifelse dest = true [ set color red ] [ set color green ] set label count nodes - 1 set is-origin? origin ]
end

;Todo: check if this can entirely be done with links and try to NOT use lists!
to establish-connection [dp1 dp2]
  ask dp1 [
    set reachable-nodes lput dp2 reachable-nodes
  ]
  ask dp2 [
    set reachable-nodes lput dp1 reachable-nodes
    create-link-with dp1
  ]
end

;to Create [k] ; create obstacle using mouse click
;  if timer > .2 and mouse-down?[
;    reset-timer create-ped mouse-xcor mouse-ycor k
;  ]
;  display
;end
;
;to Delete [k] ; delete obstacle
;  if timer > .2 and mouse-down?
;  [reset-timer create-turtles 1 [set color black setxy mouse-xcor mouse-ycor ask peds with [state = k] in-radius .5 with-min [distance myself] [die]]
;    ask turtles with [color = black][die]] display
;end

to plot!
  set-current-plot "Speed"
  set-current-plot-pen "Mean"
  plotxy time mean-speed / ticks
  set-current-plot-pen "Stddev"
  plotxy time stddev-speed / ticks
  set-current-plot "Mean flow" set-plot-y-range 0 2
  set-current-plot-pen "Spatial"
  plotxy time (mean-speed / ticks * Nb-peds / world-width / world-height)
  set-current-plot-pen "Temporal"
  plotxy time flow-cum / time / world-height
end

to set-initial-path-and-next-destination [k]
  set-all-paths self (list (list starting-point))
  set-shortest-path-and-next-destination k
end

to set-shortest-path-and-next-destination [k]
  ifelse state = 2 [
    ; users of the navigation system
    set-navigation-system-path self
  ][
    ; pax without a navigation aid
   ifelse random-path? [
    set shortest-path one-of all-paths
  ][
    ifelse easiest? [ set shortest-path first all-paths ][ set shortest-path last all-paths ]
  ]
  ]
  set next-destination item 1 shortest-path
end

to set-navigation-system-path [k]
  ; store it in 'shortest-path' of agent
  let filtered-paths all-paths ; TODO: filter paths that are not traveled yet and do not make a huge detour
  ; select least traveled route out of these
  let min-travelers 99999999999
  let min-travelers-path nobody
  ;print word "All paths: " all-paths
  foreach filtered-paths [path ->
    let current-travelers count peds with [last-node = item 0 path and next-destination = item 1 path and not (self = myself)]
    if current-travelers < min-travelers [
      ;print word "Travelers: " word current-travelers word " - path: " path
      set min-travelers current-travelers
      set min-travelers-path path
    ]
  ]
  ;print word "Min Travelers: " word min-travelers word " - min path: " min-travelers-path
  set shortest-path min-travelers-path
end

to recalculate-shortest-path [k reached]
  ; update possible paths from this node
  set all-paths map [ i -> but-first i ] (filter [ i -> item 1 i = reached ] all-paths)
  set-shortest-path-and-next-destination self
end

to set-all-paths [k from-nodes]
  let new-from-nodes from-nodes
  foreach from-nodes [i ->
   let reachable [reachable-nodes] of last i
    foreach reachable [r ->
      let new-route i
      set new-route lput r new-route

      if not member? r i [
        ifelse [is-destination?] of r [
          ; reached destination - valid route
          set all-paths lput new-route all-paths
        ][
          ; destination not reached yet - keep on searching
          set new-from-nodes lput new-route new-from-nodes
        ]
      ]
    ]
    let pos position i new-from-nodes
    set new-from-nodes remove-item pos new-from-nodes
  ]
  ifelse not empty? filter [ i ->  [is-destination?] of last i = false ] new-from-nodes [
    set-all-paths self new-from-nodes
  ][
    ;print filter [ i ->  [is-destination?] of last i = false ] new-from-nodes
    ;print word "ABORT - From nodes: " new-from-nodes
    ;print word "ALL PATH: " all-paths
  ]
end

to set-next-destination [k]
;    let available-nodes []
;    let closest-node nobody
;    foreach nodes [i ->
;      if not member? i visited-nodes [
;        set available-nodes fput i available-nodes
;      ]
;    ]
;    foreach available-nodes [i ->
;      if ((distance i + [ distance i ] of final-destination) < distance final-destination * 1.5) and distance final-destination > distance i [
;        ifelse closest-node = nobody [
;          set closest-node i
;        ][
;          if ((distance i + [ distance i ] of final-destination) < (distance closest-node + [ distance closest-node ] of final-destination)) [ set closest-node i ]
;        ]
;      ]
;    ]
;    ifelse closest-node = nobody [ set next-destination final-destination ][ set next-destination closest-node]
;  ]
end

to trace-contacts
  ask peds [
    let has-contact-to []

    ask peds in-radius contact-radius with [not (self = myself)] [
      ifelse not member? [who] of myself active-contacts [
        set active-contacts lput [who] of myself active-contacts
        set active-contacts-periods lput 1 active-contacts-periods

        if show-logs? [
         print word self word " started contact with " myself
        ]
      ] [
        let pos position [who] of myself active-contacts
        let counter-value item pos active-contacts-periods
        set counter-value counter-value + 1
        set active-contacts-periods replace-item pos active-contacts-periods counter-value
      ]

      set has-contact-to lput [who] of self has-contact-to

      set contact-distance-values contact-distance-values + 1
      set contact-distance contact-distance + distance myself
    ]

    foreach active-contacts [ x ->
      if not member? x has-contact-to [
        let pos position x active-contacts
        let counter-value item pos active-contacts-periods

        set active-contacts remove-item pos active-contacts
        set active-contacts-periods remove-item pos active-contacts-periods

        ifelse counter-value > contact-tolerance [
          set overall-contact-time overall-contact-time + counter-value
          set number-of-contacts number-of-contacts + 1
          set overall-contacts overall-contacts + 1

          if not (ped x = nobody) [
            ask ped x [
              if member? [who] of myself active-contacts [
                let pos2 position [who] of myself active-contacts

                if item pos2 active-contacts-periods != counter-value [
                  set active-contacts-periods replace-item pos2 active-contacts-periods counter-value
                ]
              ]
            ]

            if not member? x had-contact-with [
              set number-of-unique-contacts number-of-unique-contacts + 1
              set had-contact-with lput x had-contact-with

              set unique-contacts unique-contacts + 1
            ]
          ]

          if counter-value >= critical-period [
            set critical-contacts critical-contacts + 1
          ]

          if show-logs? [
            print word self word " lost contact to Person " word x word " after " word counter-value " ticks"
          ]
        ] [
          if show-logs? [
            print word "contact between " word self word " and Person " word x word " with a duration of " word counter-value " ticks will not be considered due to its short duration"
          ]
        ]
      ]
    ]

    if show-labels? [
      set label number-of-contacts
    ]
  ]
end

to move
  set time precision (time + dt) 5 tick-advance 1
  trace-contacts
  ask peds with [state > -1]
    [
      if next-destination = nobody [set-next-destination self]
      let hd towards next-destination
      let h hd
      let repx 0
      let repy 0
      if not (speedx * speedy = 0)
      [set h atan speedx speedy]
      ask peds in-cone (D) 120 with [not (self = myself)] ; self is me. myself is the agent who is asking me to do whatever I'm doing now.
      [
        ifelse distance final-destination < D or distance next-destination < D [
          set repx repx + A / 2 * exp((1 - distance myself) / D) * sin(towards myself) * (1 - cos(towards myself - h))
         set repy repy + A / 2 * exp((1 - distance myself) / D) * cos(towards myself) * (1 - cos(towards myself - h))
        ][
          set repx repx + A * exp((1 - distance myself) / D) * sin(towards myself) * (1 - cos(towards myself - h))
         set repy repy + A * exp((1 - distance myself) / D) * cos(towards myself) * (1 - cos(towards myself - h))
        ]
      ]
      ask patches in-radius (D) with [pcolor = 0]
      [
        set repx repx + A * exp((1 - distance myself) / D) * sin(towards myself) * (1 - cos(towards myself - h))
        set repy repy + A * exp((1 - distance myself) / D) * cos(towards myself) * (1 - cos(towards myself - h))
      ]

      set speedx speedx + dt * (repx + (V0 * sin hd - speedx) / Tr)
      set speedy speedy + dt * (repy + (V0 * cos hd - speedy) / Tr)
      if distance next-destination < D / 2 [
        set last-node next-destination
        ifelse distance final-destination < D / 2 [
          ;print word self " has reached its destination"
          ask in-link-neighbors [
            die
          ]
          die
        ][
          let pos (position next-destination shortest-path) + 1
          ;if (length shortest-path) < pos + 1 [
          ifelse state = 2 [ ;orange agents
            recalculate-shortest-path self next-destination
          ][
            set next-destination item pos shortest-path
          ]
          ;]
        ]
      ]
    ]

  ask peds [
    set xcor xcor + speedx * dt
    set ycor ycor + speedy * dt
  ]

  if count peds with [state > -1] < 1 [ stop ]
  if count peds with [state > -1] > 1 [set mean-speed mean-speed + mean [sqrt(speedx ^ 2 + speedy ^ 2)] of peds with [state > -1]]
  if count peds with [state > -1] > 1 [set stddev-speed stddev-speed + sqrt(variance [sqrt(speedx ^ 2 + speedy ^ 2)] of peds with [state > -1])]
  ask peds with[(xcor > 0 and xcor - speedx * dt <= 0)
    or (xcor < 0 and xcor - speedx * dt >= 0)
    or (ycor > 0 and ycor - speedy * dt <= 0)
    or (ycor < 0 and ycor - speedy * dt >= 0)]
    [set flow-cum flow-cum + 1]
  plot!
  update-plots
end
@#$#@#$#@
GRAPHICS-WINDOW
422
50
1127
756
-1
-1
17.0
1
10
1
1
1
0
0
0
1
-20
20
-20
20
0
0
1
Ticks
30.0

SLIDER
90
109
193
142
Nb-peds
Nb-peds
0
200
11.0
1
1
NIL
HORIZONTAL

BUTTON
30
126
85
160
NIL
Setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
30
163
85
196
NIL
Move
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
41
443
354
563
Mean flow
Time
Flow
0.0
0.0
0.0
0.0
true
true
"" ""
PENS
"Spatial" 1.0 0 -11053225 true "" ""
"Temporal" 1.0 0 -11881837 true "" ""

PLOT
41
320
391
440
Speed
Time
Speed
0.0
0.0
0.0
0.0
true
true
"" ""
PENS
"Mean" 1.0 0 -11053225 true "" ""
"Stddev" 1.0 0 -11881837 true "" ""

SLIDER
198
108
290
141
V0
V0
0
5
1.0
1
1
NIL
HORIZONTAL

MONITOR
47
52
105
97
Time
time
17
1
11

MONITOR
170
52
240
97
Mean speed
mean [sqrt(speedx ^ 2 + speedy ^ 2)] of peds with [state > -1]
5
1
11

MONITOR
243
52
320
97
Speed stddev
stddev-speed / ticks
5
1
11

MONITOR
108
52
166
97
Density
Nb-peds / world-width / world-height
5
1
11

MONITOR
323
52
384
97
Flow
flow-cum / time / world-height
5
1
11

PLOT
45
585
227
705
Fundamental diagram
Density
Flow
0.0
0.0
0.0
0.0
true
false
"" ""
PENS
"default" 1.0 0 -11053225 true "" ""

PLOT
238
586
398
706
Speed stddev
Density
Stddev
0.0
0.0
0.0
0.7
true
false
"" ""
PENS
"default" 1.0 0 -11053225 true "" ""

SWITCH
231
266
336
299
easiest?
easiest?
0
1
-1000

SLIDER
91
145
194
178
dt
dt
0
1
0.46
.01
1
NIL
HORIZONTAL

SLIDER
199
217
291
250
D
D
0.1
5
3.3
.1
1
NIL
HORIZONTAL

BUTTON
30
199
85
232
NIL
Move
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
199
180
291
213
A
A
0
5
1.0
.1
1
NIL
HORIZONTAL

SLIDER
199
144
291
177
Tr
Tr
.1
2
0.5
.1
1
NIL
HORIZONTAL

SLIDER
293
109
398
142
p
p
0
1
0.7
.05
1
NIL
HORIZONTAL

BUTTON
91
181
194
214
Create-destination
create -1
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
91
216
194
249
Delete-obstacle
delete -1
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
59
267
205
300
random-path?
random-path?
1
1
-1000

SWITCH
297
217
414
250
show-logs?
show-logs?
1
1
-1000

SLIDER
1133
94
1305
127
contact-radius
contact-radius
0
10
3.0
0.2
1
NIL
HORIZONTAL

SLIDER
1134
135
1306
168
contact-radius
contact-radius
1
10
3.0
1
1
NIL
HORIZONTAL

SLIDER
1134
182
1306
215
critical-period
critical-period
1
120
30.0
1
1
NIL
HORIZONTAL

SLIDER
1135
227
1307
260
contact-tolerance
contact-tolerance
0
10
5.0
1
1
NIL
HORIZONTAL

MONITOR
1324
98
1459
143
Number of contacts
overall-contacts / 2
0
1
11

MONITOR
1478
99
1714
144
Avg. number of contacts per person
overall-contacts / 2 / Nb-peds
3
1
11

MONITOR
1326
154
1507
199
Number of unique contacts
unique-contacts / 2
0
1
11

MONITOR
1523
154
1636
199
Critical contacts
critical-contacts / 2
0
1
11

MONITOR
1327
212
1497
257
Average contact duration
overall-contact-time / overall-contacts
3
1
11

MONITOR
1511
212
1680
257
Average contact distance
contact-distance / contact-distance-values
3
1
11

PLOT
1138
273
1877
757
Contacts
ticks
contacts
0.0
100.0
0.0
50.0
true
true
"" ""
PENS
"overall-contacts" 1.0 0 -16777216 true "" "plot (overall-contacts / 2)"
"average-contacts" 1.0 0 -7500403 true "" "plot (overall-contacts /  Nb-peds) * 2"
"critical-contacts" 1.0 0 -2674135 true "" "plot (critical-contacts / 2)"
"unique-contacts" 1.0 0 -955883 true "" "plot (unique-contacts / 2)"

SWITCH
1324
51
1466
84
show-circles?
show-circles?
0
1
-1000

SWITCH
1490
51
1628
84
show-labels?
show-labels?
0
1
-1000

SLIDER
1133
50
1305
83
area-of-awareness
area-of-awareness
0
20
10.0
1
1
NIL
HORIZONTAL

SWITCH
296
179
422
212
show-paths?
show-paths?
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

ambulance
false
0
Rectangle -7500403 true true 30 90 210 195
Polygon -7500403 true true 296 190 296 150 259 134 244 104 210 105 210 190
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Circle -16777216 true false 69 174 42
Rectangle -1 true false 288 158 297 173
Rectangle -1184463 true false 289 180 298 172
Rectangle -2674135 true false 29 151 298 158
Line -16777216 false 210 90 210 195
Rectangle -16777216 true false 83 116 128 133
Rectangle -16777216 true false 153 111 176 134
Line -7500403 true 165 105 165 135
Rectangle -7500403 true true 14 186 33 195
Line -13345367 false 45 135 75 120
Line -13345367 false 75 135 45 120
Line -13345367 false 60 112 60 142

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

computer server
false
0
Rectangle -7500403 true true 75 30 225 270
Line -16777216 false 210 30 210 195
Line -16777216 false 90 30 90 195
Line -16777216 false 90 195 210 195
Rectangle -10899396 true false 184 34 200 40
Rectangle -10899396 true false 184 47 200 53
Rectangle -10899396 true false 184 63 200 69
Line -16777216 false 90 210 90 255
Line -16777216 false 105 210 105 255
Line -16777216 false 120 210 120 255
Line -16777216 false 135 210 135 255
Line -16777216 false 165 210 165 255
Line -16777216 false 180 210 180 255
Line -16777216 false 195 210 195 255
Line -16777216 false 210 210 210 255
Rectangle -7500403 true true 84 232 219 236
Rectangle -16777216 false false 101 172 112 184

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

person business
false
0
Rectangle -1 true false 120 90 180 180
Polygon -13345367 true false 135 90 150 105 135 180 150 195 165 180 150 105 165 90
Polygon -7500403 true true 120 90 105 90 60 195 90 210 116 154 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 183 153 210 210 240 195 195 90 180 90 150 165
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 76 172 91
Line -16777216 false 172 90 161 94
Line -16777216 false 128 90 139 94
Polygon -13345367 true false 195 225 195 300 270 270 270 195
Rectangle -13791810 true false 180 225 195 300
Polygon -14835848 true false 180 226 195 226 270 196 255 196
Polygon -13345367 true false 209 202 209 216 244 202 243 188
Line -16777216 false 180 90 150 165
Line -16777216 false 120 90 150 165

person doctor
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -13345367 true false 135 90 150 105 135 135 150 150 165 135 150 105 165 90
Polygon -7500403 true true 105 90 60 195 90 210 135 105
Polygon -7500403 true true 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -1 true false 105 90 60 195 90 210 114 156 120 195 90 270 210 270 180 195 186 155 210 210 240 195 195 90 165 90 150 150 135 90
Line -16777216 false 150 148 150 270
Line -16777216 false 196 90 151 149
Line -16777216 false 104 90 149 149
Circle -1 true false 180 0 30
Line -16777216 false 180 15 120 15
Line -16777216 false 150 195 165 195
Line -16777216 false 150 240 165 240
Line -16777216 false 150 150 165 150

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
