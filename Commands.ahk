﻿
; Fetch latest bitcoin info from bitcoincharts api
GetBTC()
{
	static API := "http://api.bitcoincharts.com/v1/weighted_prices.json"
	
	; Read the last bitcoin data from file.
	; If there is data, load it
	; If not, use a dummy to indicate we should fetch new data
	FileRead, File, LastBTC.txt
	if File
		File := Json_ToObj(File)
	else
		File := [0,"Error"]
	
	LastTime := File[1], Elapsed := A_Now
	EnvSub, Elapsed, LastTime, Hours
	
	; If more than 1 hour has elapsed, or there is no saved last time
	if (Elapsed || !LastTime)
	{
		ToolTip, Fetching new prices
		
		; Fetch the prices
		BTC := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		BTC.Open("GET", API, False)
		BTC.Send()
		BTC := BTC.ResponseText
		
		; Decode the prices
		Rates := Json_ToObj(BTC)
		
		; Save the prices to file
		FileDelete, LastBTC.txt
		FileAppend, [%A_Now%`, %BTC%], LastBTC.txt
		
		ToolTip
	}
	else ; Read rates from file
		Rates := File[2]
	
	return Rates
}

Search(CSE, Text, More=false)
{ ; Perform a search. Available searches: Forum, Ahk, Script, Docs, g
	static Base := "https://ajax.googleapis.com/ajax/services/search/web?v=1.0"
	, json, index := 1, Google := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	
	if More
		Index++
	Else
	{
		if (CSE = "Forum")
			URI := "&cx=017058124035087163209%3A1s6iw9x3kna"
		else if (CSE = "Ahk")
			URI := "&cx=017058124035087163209%3Amvadmlmwt3m"
		else if (CSE = "Script")
			URI := "&cx=017058124035087163209%3Ag-1wna_xozc"
		else if (CSE = "Docs")
			URI := "&cx=017058124035087163209%3Az23pf7b3a3q"
		else if (CSE = "g")
			URI := ""
		else
			return "Error, not an available search engine"
		URI .= "&q=" UriEncode(Text)
		
		Google.Open("GET", Base . URI, False), Google.Send()
		json := Json_ToObj(Google.ResponseText)
		Index := 1
	}
	
	Desc := json.responseData.results[Index].titleNoFormatting
	Url := json.responseData.results[Index].url
	
	if !(Url && Desc)
		return "No results found"
	
	return htmlDecode(Desc) " - " Shorten(UriDecode(Url))
}

; Modified by GeekDude from http://goo.gl/0a0iJq
UriEncode(Uri)
{
	VarSetCapacity(Var, StrPut(Uri, "UTF-8"), 0), StrPut(Uri, &Var, "UTF-8")
	f := A_FormatInteger
	SetFormat, IntegerFast, H
	While Code := NumGet(Var, A_Index - 1, "UChar")
		If (Code >= 0x30 && Code <= 0x39 ; 0-9
			|| Code >= 0x41 && Code <= 0x5A ; A-Z
	|| Code >= 0x61 && Code <= 0x7A) ; a-z
	Res .= Chr(Code)
	Else
		Res .= "%" . SubStr(Code + 0x100, -1)
	SetFormat, IntegerFast, %f%
	Return, Res
}

UriDecode(Uri)
{
	Pos := 1
	While Pos := RegExMatch(Uri, "i)(%[\da-f]{2})+", Code, Pos)
	{
		VarSetCapacity(Var, StrLen(Code) // 3, 0), Code := SubStr(Code,2)
		Loop, Parse, Code, `%
			NumPut("0x" A_LoopField, Var, A_Index-1, "UChar")
		StringReplace, Uri, Uri, `%%Code%, % StrGet(&Var, "UTF-8"), All
	}
	Return, Uri
}

HtmlDecode(Text)
{
	html := ComObjCreate("htmlfile")
	html.write(Text)
	return html.body.innerText
}

GetPosts(Max = 4, Timeout=10)
{
	static Posts := [0], UA := "Mozilla/5.0 (X11; Linux"
	. " x86_64; rv:12.0) Gecko/20100101 Firefox/21.0"
	, Feed := "http://ahkscript.org/boards/feed.php"
	
	if (A_TickCount - Posts[1] > 1 * 60 * 1000 || Max < 0) ; 1 minute
	{
		http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		http.Open("GET", Feed, True) ; Async
		http.setRequestHeader("User-Agent", UA)
		http.Send()
		
		; Wait for data or timeout
		TickCount := A_TickCount
		While A_TickCount - TickCount < Timeout * 1000
		{
			Sleep, 100
			Try ; If it errors, the data has not been recieved yet
				Rss := http.responseText, TickCount := 0 ;, AppendLog(A_Index)
		}
		if !Rss
			return "Error: Server timeout"
		
		; Load XML
		xml:=ComObjCreate("MSXML2.DOMDocument")
		xml.loadXML(Rss)
		if !entries := xml.selectnodes("/feed/entry")
			return "Error: Malformed XML"
		
		; Read entries
		Posts := [A_TickCount]
		While entry := entries.item[A_Index-1]
		{
			Title := HtmlDecode(entry.selectSingleNode("title").text)
			Author := entry.selectSingleNode("author/name").text
			Url := Shorten(entry.selectSingleNode("link/@href").text)
			Posts.Insert({"Author":Author, "Title":Title, "Url":Url})
		}
	}
	
	Out := Posts.Clone()
	Out.Remove(Abs(Max)+2, 17) ; The key after the last one we want, and +1 because of timestamp
	
	return Out
}

NewPosts(Max=4)
{
	Max := Floor(Max)
	if (Max < -7 || Max > 7 || !Max)
		Max := 4
	
	Posts := GetPosts(Max)
	if !IsObject(Posts)
		return Posts
	
	if (Cached := (A_TickCount-Posts.Remove(1)) // 1000)
		Out := "Information is " Cached " seconds old (use negative to force refresh)`n"
	
	for each, Post in Posts
		Out .= Post.Author " - " Post.Title " - " Post.Url "`n"
	
	return Out
}

NewNique(Max=4)
{
	Max := Floor(Max)
	if (Max < -7 || Max > 7 || !Max)
		Max := 4
	
	Posts := GetPosts(Max > 0 ? 16 : -16)
	if !IsObject(Posts)
		return Posts
	
	if (Cached := (A_TickCount-Posts.Remove(1)) // 1000)
		Out := "Information is " Cached " seconds old (use negative to force refresh)`n"
	
	Max := Abs(Max), i := 0
	for each, Post in Posts
	{
		if InStr(Post.Title, " • Re: ")
			continue
		if (++i >= Max)
			Break
		Out .= Post.Author " - " Post.Title " - " Post.Url "`n"
	}
	
	return Out ? Out : "No new posts"
}

Shorten(LongUrl, SetKey="")
{
	static Shortened := {"http://www.autohotkey.net/": "http://ahk.me/sqTsfk"
	, "http://www.autohotkey.com/": "http://ahk.me/sDikbQ"
	, "http://www.autohotkey.com/forum/": "http://ahk.me/rJiLHk"
	, "http://www.autohotkey.com/docs/Tutorial.htm": "http://ahk.me/uKJ4oh"
	, "http://github.com/polyethene/robokins": "http://git.io/robo"
	, "http://ahkscript.org/": "http://ahk4.me/QMmuVo"}
	, http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	, Base := "http://api.bitly.com/v3/shorten"
	, login, apiKey
	
	if SetKey
	{
		apiKey := SetKey
		login := LongUrl
		return
	}
	
	if (Shortened.HasKey(LongUrl))
		return Shortened[LongUrl]
	
	if !(login && apiKey)
		return LongUrl
	
	Url := Base
	. "?login=" login
	. "&apiKey=" apiKey
	. "&longUrl=" UriEncode(Trim(LongUrl, " `r`n`t"))
	. "&format=txt"
	
	http.Open("GET", Url, False), http.Send()
	ShortUrl := Trim(http.responseText, " `r`n`t")
	Shortened.Insert(LongUrl, ShortUrl)
	
	return ShortUrl
}

ShowHelp(Command)
{
	static Commands := Ini_Read("Help.ini")
	if !Commands.HasKey(Command)
		Command := "Help"
	
	return "Usage: " Commands[Command].Usage "`n" Commands[Command].Desc
}

