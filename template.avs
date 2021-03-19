#############################################################################
#######################   -Options, Settings-   #############################
#############################################################################

Logging = false
display_group=true
displayFramNum=false
display_subtitles = true
display_timecode = false

# Adding blank frames in front or back of the VidClp
Front_FramePadding = 0
Back_FramePadding = 0

#############################################################################
##################   -Should Not Need To Change-   ##########################
#############################################################################

vidfile = "{{?VIDEO_FILE}}"
subfile = "{{?SUBTITLE_FILE}}"
group = "{{?GROUP_NAME}}"

## creating file and set path for future log entries:
(Logging) ? Eval("""
	folder = ScriptDir()
	(RightStr(folder, 1) == "\") ?
   \     SetLogParams(folder + group + "_ScriptLog.log", LOG_INFO): SetLogParams(folder + "\" + group + "_ScriptLog.log", LOG_INFO)
	LogMsg("Starting Logger", LOG_INFO)
	""")
\:nop()  

c1  = FFVideoSource (vidfile, enable10bithack=false, colorspace="YV12")
c2  = FFVideoSource (vidfile, enable10bithack=true, varprefix="c1_", colorspace="YV12")

(StrLen(subfile) == 0) ? Eval("""
    F_blank1 = BlankClip(c1, length= Front_FramePadding)  
    B_blank1 = BlankClip(c1, length= Back_FramePadding)
    c1 = F_blank1+c1+B_blank1
    
    F_blank2 = BlankClip(c2, length= Front_FramePadding)  
    B_blank2 = BlankClip(c2, length= Back_FramePadding)
    c2 = F_blank2+c2+B_blank2    
    
    """):
\nop()

w   = c1.Width ()
h   = c1.Height ()
wm4 = (w + 3) / 4 * 4
hm4 = (h + 3) / 4 * 4
b10 = (c2.Height () > c1.Height ())

target_width = {{?TARGET_RES_X}}
target_height = {{?TARGET_RES_Y}}

matrix   = (c1_FFCOLOR_SPACE == 1) ? "709"
\        : (c1_FFCOLOR_SPACE >= 5) ? "601" : Dither_undef ()
par      = (c1_FFSAR_NUM > 0 && c1_FFSAR_DEN > 0)
\        ? Float (c1_FFSAR_NUM) / Float (c1_FFSAR_DEN)
\        : Dither_undef ()
tv_range = (c1_FFCOLOR_RANGE != 2)

(b10) ? c2 : c1

#Adding Subs based on the file ext
Subs = (StrLen(subfile) > 0 && display_subtitles) ?
\      (RightStr(LCase(subfile), 3) == "sup") ?
\         	(b10) ? Dither_limit_dif16(DitherPost(mode=-1).SupTitle(subfile).Dither_convert_8_to_16 (), thr=1.0, elast=2.0) : SupTitle(subfile)
\          :(RightStr(LCase(subfile), 3) == "sub") ?
\         	(b10) ? Dither_limit_dif16(DitherPost(mode=-1).VSFilter_Vobsub(subfile).Dither_convert_8_to_16 (), thr=1.0, elast=2.0) : VSFilter_Vobsub(subfile)
\          :(b10) ? Dither_limit_dif16(DitherPost(mode=-1).AssRender(subfile).Dither_convert_8_to_16 (), thr=1.0, elast=2.0) : AssRender(subfile)
\: nop()

#Add blank frames if needed
(StrLen(subfile) > 0 && display_subtitles) ? Eval("""
    F_blank2 = BlankClip(Subs, length= Front_FramePadding)  
    B_blank2 = BlankClip(Subs, length= Back_FramePadding)
    F_blank2+Subs+B_blank2
    """):
\nop()



(VersionNumber () >= 2.6) ? last
\ : (b10) ? Dither_addborders16 (0, 0, wm4 - w, hm4 - h)
\         : AddBorders (0, 0, wm4 - w, hm4 - h)

(target_width != c1.Width() || target_height != c1.Height()) ? Dither_srgb_display (lsb_in=b10, matrix=matrix, par=par, tv_range=tv_range, w=target_width, h=target_height)
\ :                                                            Dither_srgb_display (lsb_in=b10, matrix=matrix, par=par, tv_range=tv_range)

screenShotGroup = (target_width > c1.Width() || target_height > c1.Height()) ? group + "_Upscaled" : group

cmt1 = (target_width > c1.Width() || target_height > c1.Height()) ? group + "\nupscaled" : group
cmt2 = (display_group) ? 
\                 cmt1 : ""

FFInfoEx(framenum=displayFramNum,vfrtime=display_timecode, cfrtime=false, frametype=false, x=last.width-6, y=4, cmt=cmt2, align=9, shorttime=true)
