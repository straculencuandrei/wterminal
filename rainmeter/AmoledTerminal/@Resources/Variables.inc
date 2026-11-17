[Variables]
; AMOLED Dark-Grey Transparent Terminal Palette
BgColor=5,5,7,212
BgHover=14,14,18,232
BorderColor=255,255,255,28
HighlightBorder=212,212,216,95
TextPrimary=244,244,245,245
TextSecondary=161,161,170,225
TextMuted=113,113,122,210
Accent=228,228,231,255
TermGreen=74,222,128,255
BarTrack=255,255,255,20

; Ubuntu Typography
FontMono=Ubuntu
FontText=Ubuntu

; Time Format: %H:%M for 24h, %I:%M %p for 12h
TimeFormat=%H:%M
DateFormat=%a %Y-%m-%d

; Antigravity token telemetry limits (context window / rolling 5h, 24h, weekly budgets)
AgyContextLimit=1000000
Agy5hLimit=5000000
AgyDailyLimit=20000000
AgyWeeklyLimit=30000000

; Auto-managed display scale & layout state (updated by Layout.lua / reset-widgets.ps1)
S=1.00
LastAreaKey=
PendingLayout=0
