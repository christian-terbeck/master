globals [overall-contacts overall-contact-time unique-contacts critical-contacts contact-distance-values contact-distance]

breed [people person]
people-own [target number-of-unique-contacts number-of-contacts had-contact-with active-contacts active-contacts-periods]

breed [houses house]
breed [circles circle]

to setup
  clear-all
  set-default-shape houses "house"
  set-default-shape circles "circle 2"

  ;; CREATE-ORDERED-<BREEDS> distributes the houses evenly
  create-ordered-houses number-of-houses
    [ fd max-pxcor ]

  create-people number-of-people [
    setxy random-xcor random-ycor
    set target one-of houses
    set had-contact-with []
    set active-contacts []
    set active-contacts-periods []
    face target
  ]

  if show-circles?
    [
      ask people [
        make-circle
      ]
    ]

  reset-ticks
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

to go
  ask people [
    let has-contact-to []

    ask people in-radius contact-radius with [not (self = myself)] [
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

          ask person x [
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

    if distance target = 0
      [ set target one-of houses
        face target ]
    ;; move towards target.  once the distance is less than 1,
    ;; use move-to to land exactly on the target.

    ifelse distance target < 1
      [ move-to target ]
      [ fd 1 ]
  ]

  tick
end
@#$#@#$#@
GRAPHICS-WINDOW
320
10
1121
812
-1
-1
13.0
1
10
1
1
1
0
0
0
1
-30
30
-30
30
1
1
1
ticks
30.0

BUTTON
61
321
146
354
setup
setup
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
146
321
231
354
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
60
41
230
74
number-of-people
number-of-people
1
50
13.0
1
1
NIL
HORIZONTAL

SLIDER
60
76
230
109
number-of-houses
number-of-houses
3
20
20.0
1
1
NIL
HORIZONTAL

PLOT
1168
20
1852
398
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
"average-contacts" 1.0 0 -9276814 true "" "plot (overall-contacts / count turtles) * 2"
"unique-contacts" 1.0 0 -955883 true "" "plot (unique-contacts / 2)"
"critical-contacts" 1.0 0 -2674135 true "" "plot (critical-contacts / 2)"

MONITOR
1168
407
1289
452
Number of contacts
overall-contacts / 2
0
1
11

MONITOR
1299
407
1512
452
Avg. number of contacts per Person
overall-contacts / 2 / count people
5
1
11

SWITCH
61
180
189
213
show-circles?
show-circles?
0
1
-1000

SLIDER
60
110
232
143
contact-radius
contact-radius
0
15
3.5
.1
1
NIL
HORIZONTAL

SWITCH
61
215
187
248
show-labels?
show-labels?
0
1
-1000

MONITOR
1169
509
1303
554
Avg. contact duration
overall-contact-time / overall-contacts
5
1
11

SWITCH
61
250
178
283
show-logs?
show-logs?
1
1
-1000

MONITOR
1169
459
1331
504
Number of unique contacts
unique-contacts / 2
5
1
11

SLIDER
60
145
232
178
critical-period
critical-period
10
150
43.0
1
1
NIL
HORIZONTAL

MONITOR
1339
459
1498
504
Number of critical contacts
critical-contacts / 2
5
1
11

SLIDER
61
284
233
317
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
1310
509
1444
554
Avg. contact distance
contact-distance / contact-distance-values
5
1
11

@#$#@#$#@
## WHAT IS IT?

This code example demonstrates how to have a turtle approach a target location a step at a time.

## HOW IT WORKS

The `people` breed has a variable called `target`, which holds the agent the person is moving towards.

The `face` command points the person towards the target.  `fd` moves the person.  `distance` measures the distance to the target.

When a person reaches their target, they pick a random new target.

<!-- 2008 -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

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
