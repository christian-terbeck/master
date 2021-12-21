breed [peds ped] ; define agents
breed [decision-points decision-point]
breed [circles circle]
; globals accessible by all agents and can be used anywhere in the model
globals [time mean-speed stddev-speed flow-cum
  overall-contacts overall-contact-time unique-contacts critical-contacts contact-distance-values contact-distance; contact tracing
]
peds-own [speedx speedy state final-destination next-destination first-reached starting-point last-decision-point all-paths shortest-path
  number-of-unique-contacts number-of-contacts had-contact-with active-contacts active-contacts-periods ; for contact tracing
]
decision-points-own [reachable-decision-points area-of-awareness is-destination is-origin]
; state = -1 -> obstacle
; state = 2 -> moving pedestrian

to setup
  clear-all reset-ticks
  import-pcolors "floorplans/example.png"
  set-default-shape circles "circle 2"
  set-decision-points
  set-agents
  if show-circles?
    [
      ask peds [
        ;make-circle
      ]
    ]
  if logs? [print "--- NEW SIMULATION ---"]
end

to make-circle
  hatch-circles 1
  [ set size contact-radius
    set color lput 64 extract-rgb color
    __set-line-thickness 0.5
    create-link-from myself
    [ tie
      hide-link ] ]
end

to set-decision-points
  c-decision-point -10 -2 false false    ; 0
  c-decision-point 16 -2 false false     ; 1
  c-decision-point 12 -6 false false     ; 2
  c-decision-point 13 -12 true false     ; 3
  c-decision-point 0 -2 false false      ; 4
  c-decision-point -10 -10 false true    ; 5
  c-decision-point 13 13 false true      ; 6
  c-decision-point -13 13 false true     ; 7
  c-decision-point 0 13 false true       ; 8
  c-decision-point 0 -13 false true      ; 9
  c-decision-point -18 15 false true     ; 10
  c-decision-point -18 -2 false true     ; 11
  c-decision-point -18 -15 false true    ; 12
  c-decision-point 8 17.5 false true     ; 13
  establish-connection decision-point 0 decision-point 7
  establish-connection decision-point 0 decision-point 4
  establish-connection decision-point 0 decision-point 5
  establish-connection decision-point 4 decision-point 9
  establish-connection decision-point 4 decision-point 8
  establish-connection decision-point 4 decision-point 2
  establish-connection decision-point 4 decision-point 1
  establish-connection decision-point 9 decision-point 2
  establish-connection decision-point 9 decision-point 3
  establish-connection decision-point 2 decision-point 1
  establish-connection decision-point 2 decision-point 3
  establish-connection decision-point 1 decision-point 6
  establish-connection decision-point 6 decision-point 8


  establish-connection decision-point 10 decision-point 7
  establish-connection decision-point 11 decision-point 0
  establish-connection decision-point 12 decision-point 5
  establish-connection decision-point 13 decision-point 8
  establish-connection decision-point 13 decision-point 6
end

to set-agents
  repeat nb-peds [c-ped 0 0 0]
  ask n-of round (p * nb-peds) peds [set state 2 set color orange]
end

to c-ped  [x y k]
  let randfour random 4
  ;if k = 0 [ask one-of patches with [not any? peds-here and pcolor = white] [set x pxcor set y pycor]]
  let s-point nobody
  if k = 0 [ask one-of decision-points with [is-destination = false] [set x pxcor set y pycor set s-point self]]
  create-peds 1 [
    set shape "person business"
    set color cyan
    set xcor x + random-normal 0 .2
    set ycor y + random-normal 0 .2
    set final-destination one-of decision-points with [is-destination = true]
    set next-destination nobody
    set first-reached false
    set starting-point s-point
    set last-decision-point s-point
    set all-paths []
    set shortest-path [] set-initial-path-and-next-destination k
    set had-contact-with []
    set active-contacts []
    set active-contacts-periods []
    face decision-point 1

    if k = -1 [set color green set state -1]
  ]
end

to c-decision-point [x y dest origin]
  create-decision-points 1 [ set xcor x set ycor y set reachable-decision-points [] set is-destination dest set shape "circle" ifelse dest = true [ set color red ] [ set color green ] set label count decision-points - 1 set is-origin origin ]
end

to establish-connection [dp1 dp2]
  ask dp1 [
    set reachable-decision-points fput dp2 reachable-decision-points
  ]
  ask dp2 [
    set reachable-decision-points fput dp1 reachable-decision-points
    create-link-with dp1
  ]
end

to Create [k] ; create obstacle using mouse click
  if timer > .2 and mouse-down?[
    reset-timer c-ped mouse-xcor mouse-ycor k
  ]
  display
end

to Delete [k] ; delete obstacle
  if timer > .2 and mouse-down?
  [reset-timer create-turtles 1 [set color black setxy mouse-xcor mouse-ycor ask peds with [state = k] in-radius .5 with-min [distance myself] [die]]
    ask turtles with [color = black][die]] display
end

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
  print word "All paths: " all-paths
  foreach filtered-paths [path ->
    let current-travelers count peds with [last-decision-point = item 0 path and next-destination = item 1 path and not (self = myself)]
    if current-travelers < min-travelers [
      print word "Travelers: " word current-travelers word " - path: " path
      set min-travelers current-travelers
      set min-travelers-path path
    ]
  ]
  print word "Min Travelers: " word min-travelers word " - min path: " min-travelers-path
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
   let reachable [reachable-decision-points] of last i
    foreach reachable [r ->
      let new-route i
      set new-route lput r new-route
      ifelse member? r i [
        ; waling a circle - do not include that one
        ; do nothing
      ] [
        ifelse [is-destination] of r [
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
  ifelse not empty? filter [ i ->  [is-destination] of last i = false ] new-from-nodes [
    set-all-paths self new-from-nodes
  ][
    ;print filter [ i ->  [is-destination] of last i = false ] new-from-nodes
    ;print word "ABORT - From nodes: " new-from-nodes
    ;print word "ALL PATH: " all-paths
  ]
end

to set-next-destination [k]

;    let available-decision-points []
;    let closest-decision-point nobody
;    foreach decision-points [i ->
;      if not member? i visited-decision-points [
;        set available-decision-points fput i available-decision-points
;      ]
;    ]
;    foreach available-decision-points [i ->
;      if ((distance i + [ distance i ] of final-destination) < distance final-destination * 1.5) and distance final-destination > distance i [
;        ifelse closest-decision-point = nobody [
;          set closest-decision-point i
;        ][
;          if ((distance i + [ distance i ] of final-destination) < (distance closest-decision-point + [ distance closest-decision-point ] of final-destination)) [ set closest-decision-point i ]
;        ]
;      ]
;    ]
;    ifelse closest-decision-point = nobody [ set next-destination final-destination ][ set next-destination closest-decision-point]
;  ]
end

to trace-contacts
  ask peds [
    let has-contact-to []

    ask peds in-radius contact-radius with [not (self = myself)] [
      ifelse not member? [who] of myself active-contacts [
        set active-contacts lput [who] of myself active-contacts
        set active-contacts-periods lput 1 active-contacts-periods

        if logs? [
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

          if logs? [
            print word self word " lost contact to Person " word x word " after " word counter-value " ticks"
          ]
        ] [
          if logs? [
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
        set last-decision-point next-destination
        ifelse distance final-destination < D / 2 [die][
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
36.0
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
0.32
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
308
198
411
231
logs?
logs?
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
20.0
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
120
20.0
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
29.0
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
3.0
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
17
1
11

MONITOR
1478
99
1714
144
Avg. number of contacts per person
overall-contacts / 2 / Nb-peds
5
1
11

MONITOR
1326
154
1507
199
Number of unique contacts
unique-contacts / 2
17
1
11

MONITOR
1523
154
1636
199
Critical contacts
critical-contacts / 2
17
1
11

MONITOR
1327
212
1497
257
Average contact duration
overall-contact-time / overall-contacts
17
1
11

MONITOR
1511
212
1680
257
Average contact distance
contact-distance / contact-distance-values
17
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
1159
46
1301
79
show-circles?
show-circles?
0
1
-1000

SWITCH
1325
46
1463
79
show-labels?
show-labels?
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

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

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

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

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

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

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

person police
false
0
Polygon -1 true false 124 91 150 165 178 91
Polygon -13345367 true false 134 91 149 106 134 181 149 196 164 181 149 106 164 91
Polygon -13345367 true false 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Polygon -13345367 true false 120 90 105 90 60 195 90 210 116 158 120 195 180 195 184 158 210 210 240 195 195 90 180 90 165 105 150 165 135 105 120 90
Rectangle -7500403 true true 123 76 176 92
Circle -7500403 true true 110 5 80
Polygon -13345367 true false 150 26 110 41 97 29 137 -1 158 6 185 0 201 6 196 23 204 34 180 33
Line -13345367 false 121 90 194 90
Line -16777216 false 148 143 150 196
Rectangle -16777216 true false 116 186 182 198
Rectangle -16777216 true false 109 183 124 227
Rectangle -16777216 true false 176 183 195 205
Circle -1 true false 152 143 9
Circle -1 true false 152 166 9
Polygon -1184463 true false 172 112 191 112 185 133 179 133
Polygon -1184463 true false 175 6 194 6 189 21 180 21
Line -1184463 false 149 24 197 24
Rectangle -16777216 true false 101 177 122 187
Rectangle -16777216 true false 179 164 183 186

person soldier
false
0
Rectangle -7500403 true true 127 79 172 94
Polygon -10899396 true false 105 90 60 195 90 210 135 105
Polygon -10899396 true false 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Polygon -10899396 true false 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -6459832 true false 120 90 105 90 180 195 180 165
Line -6459832 false 109 105 139 105
Line -6459832 false 122 125 151 117
Line -6459832 false 137 143 159 134
Line -6459832 false 158 179 181 158
Line -6459832 false 146 160 169 146
Rectangle -6459832 true false 120 193 180 201
Polygon -6459832 true false 122 4 107 16 102 39 105 53 148 34 192 27 189 17 172 2 145 0
Polygon -16777216 true false 183 90 240 15 247 22 193 90
Rectangle -6459832 true false 114 187 128 208
Rectangle -6459832 true false 177 187 191 208

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

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