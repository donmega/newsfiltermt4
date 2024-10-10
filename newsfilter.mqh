//+------------------------------------------------------------------+
//|                                                      News Filter  |
//|                                              Copyright 2018, RRS    |
//|                                              example@example.com    |
//+------------------------------------------------------------------+

#property copyright "NewsFilter"
#property link      "https://example.com"

#import "urlmon.dll"
int URLDownloadToFileW(int pCaller, string szURL, string szFileName, int dwReserved, int Callback);
#import

//---
#define INAME     "FFCPing" + _Symbol
#define TITLE     0
#define COUNTRY   1
#define DATE      2
#define TIME      3
#define IMPACT    4
#define FORECAST  5
#define PREVIOUS  6

//-------- Input Parameters --------
input string p01 = "***NEWS FILTER***";              //******** NEWS FILTER ********
input bool news_High = true;                         // Use High News Filter
input bool news_High_Line = true;                    // Use High News Line (Red Line)
input int minBefore = 30;                            // Minutes Before High Impact News
input int minAfter = 30;                             // Minutes After High Impact News
input bool news_Medium = false;                       // Use Medium News Filter
input bool news_Medium_Line = false;                  // Use Medium News Line (Orange Line)
input int minBefore1 = 30;                            // Minutes Before Medium Impact News
input int minAfter1 = 30;                             // Minutes After Medium Impact News
input bool news_Low = false;                          // Use Low News Filter
input bool news_Low_Line = false;                     // Use Low News Line (Yellow Line)
input int minBefore2 = 30;                            // Minutes Before Low Impact News
input int minAfter2 = 30;                             // Minutes After Low Impact News

//-------- Global Variables --------
int comment_on = 1;
string News_Trade_Status = "Paused";

string xmlFileName;
string sData;
string Event[200][7];
string eTitle[200][200], eCountry[200][200], eImpact[200][200], eForecast[200][200], ePrevious[200][200];
bool assignVal = true;
int eMinutes[10];
datetime eTime[200][200];

datetime xmlModified;  // Corrected spelling
int TimeOfDay;
datetime Midnight;
bool IsEvent;

//-------- Initialization Function --------
int OnInit()
{
    //--- Get today's time
    TimeOfDay = (int)TimeLocal() % 86400;
    Midnight = TimeLocal() - TimeOfDay;

    //--- Set XML file name
    xmlFileName = INAME + "-ffcal_week_this.xml";

    //--- Check existence and download/read XML
    if (!FileIsExist(xmlFileName))
    {
        xmlDownload();
        xmlRead();
    }
    else
    {
        xmlRead();
    }

    //--- Get last modification time
    xmlModified = (datetime)FileGetInteger(xmlFileName, FILE_MODIFY_DATE, false);  // Corrected spelling

    //--- Check for updates
    if (!FileIsExist(xmlFileName))
    {
        if (xmlModified < TimeLocal() - (4 * 3600))
        {
            Print(INAME + ": XML file is out of date");
            xmlUpdate();
        }
        //--- Set timer to update old XML file every hour (3600 seconds)
        EventSetTimer(3600);
    }
    assignVal = true;

    Print(INAME + ": Initialized successfully.");
    return (INIT_SUCCEEDED);
}

//-------- Deinitialization Function --------
void OnDeinit(const int reason)
{
    //--- Remove all created objects to clean up the chart
    ObjectsDeleteAll(0, OBJ_VLINE);
    ObjectsDeleteAll(0, OBJ_TEXT);
    Print(INAME + ": Deinitialized and cleaned up objects.");
}

//-------- Tick Function --------
void OnTick()
{
    // Check if the XML file has been modified since the last check
    datetime currentModified = (datetime)FileGetInteger(xmlFileName, FILE_MODIFY_DATE, false);
    if (currentModified > xmlModified)  // Corrected spelling
    {
        Print(INAME + ": Detected updated XML file. Reloading data.");
        xmlRead();
        xmlModified = currentModified;  // Corrected spelling
        assignVal = true; // Reassign values based on the new XML data
    }

    // Update News Trade Status based on upcoming news
    if (isNewsPause(_Symbol, 0))
    {
        if (News_Trade_Status != "Paused")
        {
            News_Trade_Status = "Paused";
            Print(INAME + ": Trading Paused due to upcoming news.");
        }
    }
    else
    {
        if (News_Trade_Status != "Active")
        {
            News_Trade_Status = "Active";
            Print(INAME + ": Trading Active. No immediate news impact.");
        }
    }

    // Display the current news status on the chart
    string display_text = "News Status: " + News_Trade_Status;
    Comment(display_text);
}

//-------- Timer Function --------
void OnTimer()
{
    //--- Update XML file periodically
    assignVal = true;
    Print(INAME + ": Timer triggered. Checking for XML updates.");
    xmlUpdate();
}

//-------- Helper Functions --------

//+------------------------------------------------------------------+
//| Create Text Object                                               |
//+------------------------------------------------------------------+
bool TextCreate(const long chart_ID = 0,                // chart's ID
                const string name = "Text",               // object name
                const int sub_window = 0,                 // subwindow index
                datetime time = 0,                        // anchor point time
                double price = 0,                         // anchor point price
                const string text = "Text",               // the text itself
                const color clr = clrRed,                 // color
                const string font = "Arial",              // font
                const int font_size = 10,                 // font size
                const double angle = 0.0,                  // text slope
                const ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_LOWER, // anchor type
                const bool back = false,                  // in the background
                const bool selection = false,             // highlight to move
                const bool hidden = true,                 // hidden in the object list
                const long z_order = 0)                   // priority for mouse click
{
    //--- Reset the error value
    ResetLastError();
    //--- Create Text object
    if (!ObjectCreate(chart_ID, name, OBJ_TEXT, sub_window, time, price))
    {
        Print(__FUNCTION__,
              ": Failed to create \"Text\" object! Error code = ", GetLastError());
        return (false);
    }
    //--- Set the text
    ObjectSetString(chart_ID, name, OBJPROP_TEXT, text);
    //--- Set text font
    ObjectSetString(chart_ID, name, OBJPROP_FONT, font);
    //--- Set font size
    ObjectSetInteger(chart_ID, name, OBJPROP_FONTSIZE, font_size);
    //--- Set the slope angle of the text
    ObjectSetDouble(chart_ID, name, OBJPROP_ANGLE, angle);
    //--- Set anchor type
    ObjectSetInteger(chart_ID, name, OBJPROP_ANCHOR, anchor);
    //--- Set color
    ObjectSetInteger(chart_ID, name, OBJPROP_COLOR, clr);
    //--- Display in the foreground (false) or background (true)
    ObjectSetInteger(chart_ID, name, OBJPROP_BACK, back);
    //--- Enable or disable the mode of moving the object by mouse
    ObjectSetInteger(chart_ID, name, OBJPROP_SELECTABLE, selection);
    ObjectSetInteger(chart_ID, name, OBJPROP_SELECTED, selection);
    //--- Hide or display graphical object name in the object list
    ObjectSetInteger(chart_ID, name, OBJPROP_HIDDEN, hidden);
    //--- Set the priority for receiving the event of a mouse click in the chart
    ObjectSetInteger(chart_ID, name, OBJPROP_ZORDER, z_order);
    //--- Successful execution
    return (true);
}

//+------------------------------------------------------------------+
//| Create Vertical Line                                             |
//+------------------------------------------------------------------+
bool VLineCreate(const long chart_ID = 0,                // chart's ID
                const string name = "VLine",               // line name
                const int sub_window = 0,                  // subwindow index
                datetime time = 0,                         // line time
                const color clr = clrRed,                  // line color
                const ENUM_LINE_STYLE style = STYLE_SOLID, // line style
                const int width = 1,                        // line width
                const bool back = false,                   // in the background
                const bool selection = false,              // highlight to move
                const bool hidden = true,                  // hidden in the object list
                const long z_order = 0)                    // priority for mouse click
{
    //--- Create a vertical line
    if (!ObjectCreate(chart_ID, name, OBJ_VLINE, sub_window, time, 0))
    {
        Print(__FUNCTION__,
              ": Failed to create a vertical line! Error code = ", GetLastError());
        return (false);
    }
    //--- Set line properties
    ObjectSetInteger(chart_ID, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(chart_ID, name, OBJPROP_STYLE, style);
    ObjectSetInteger(chart_ID, name, OBJPROP_WIDTH, width);
    ObjectSetInteger(chart_ID, name, OBJPROP_BACK, back);
    ObjectSetInteger(chart_ID, name, OBJPROP_SELECTABLE, selection);
    ObjectSetInteger(chart_ID, name, OBJPROP_SELECTED, selection);
    ObjectSetInteger(chart_ID, name, OBJPROP_HIDDEN, hidden);
    ObjectSetInteger(chart_ID, name, OBJPROP_ZORDER, z_order);
    //--- Successful execution
    return (true);
}

//+------------------------------------------------------------------+
//| Create Horizontal Line                                           |
//+------------------------------------------------------------------+
bool HLineCreate(const long chart_ID = 0,                // chart's ID
                const string name = "HLine",               // line name
                const int sub_window = 0,                  // subwindow index
                double price = 0,                          // line price
                const color clr = clrRed,                  // line color
                const ENUM_LINE_STYLE style = STYLE_SOLID, // line style
                const int width = 1,                        // line width
                const bool back = false,                   // in the background
                const bool selection = false,              // highlight to move
                const bool hidden = true,                  // hidden in the object list
                const long z_order = 0)                    // priority for mouse click
{
    //--- Reset the error value
    ResetLastError();
    //--- Create a horizontal line
    if (!ObjectCreate(chart_ID, name, OBJ_HLINE, sub_window, 0, price))
    {
        Print(__FUNCTION__,
              ": Failed to create a horizontal line! Error code = ", GetLastError());
        return (false);
    }
    //--- Set line properties
    ObjectSetInteger(chart_ID, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(chart_ID, name, OBJPROP_STYLE, style);
    ObjectSetInteger(chart_ID, name, OBJPROP_WIDTH, width);
    ObjectSetInteger(chart_ID, name, OBJPROP_BACK, back);
    ObjectSetInteger(chart_ID, name, OBJPROP_SELECTABLE, selection);
    ObjectSetInteger(chart_ID, name, OBJPROP_SELECTED, selection);
    ObjectSetInteger(chart_ID, name, OBJPROP_HIDDEN, hidden);
    ObjectSetInteger(chart_ID, name, OBJPROP_ZORDER, z_order);
    //--- Successful execution
    return (true);
}

//+------------------------------------------------------------------+
//| Download XML File                                                |
//+------------------------------------------------------------------+
void xmlDownload()
{
    Sleep(3000);
    //---
    ResetLastError();
    /*
    string sUrl = "http://nfs.faireconomy.media/ff_calendar_thisweek.xml";
    string FilePath = StringConcatenate(TerminalInfoString(TERMINAL_DATA_PATH), "\\MQL4\\files\\", xmlFileName);
    int FileGet = URLDownloadToFileW(NULL, sUrl, FilePath, 0, NULL);
    if (FileGet == 0)
        PrintFormat(INAME + ": %s file downloaded successfully!", xmlFileName);
    //--- Check for errors
    else
        PrintFormat(INAME + ": failed to download %s file, Error code = %d", xmlFileName, GetLastError());
    */

    string cookie = NULL, headers;
    string reqheaders = "User-Agent: Mozilla/4.0\r\n";
    char post[], result[];
    int res;
    string url = "http://nfs.faireconomy.media/ff_calendar_thisweek.xml";
    ResetLastError();
    int timeout = 5000;
    res = WebRequest("GET", url, reqheaders, timeout, post, result, headers);
    if (res == -1)
    {
        Print("Error in WebRequest. Error code  =", GetLastError());
        //--- Perhaps the URL is not listed, display a message about the necessity to add the address
        MessageBox("Add the address '" + url + "' in the list of allowed URLs on tab 'Expert Advisors'", "Error", MB_ICONINFORMATION);
    }
    else
    {
        //--- Load successfully
        PrintFormat(INAME + ": The file has been successfully loaded, File size =%d bytes.", ArraySize(result));
        //--- Save the data to a file
        int filehandle = FileOpen(xmlFileName, FILE_WRITE | FILE_BIN);
        //--- Checking errors
        if (filehandle != INVALID_HANDLE)
        {
            //--- Save the contents of the result[] array to a file
            FileWriteArray(filehandle, result, 0, ArraySize(result));
            //--- Close the file
            FileClose(filehandle);
            Print(INAME + ": XML file saved successfully.");
        }
        else
            Print("Error in FileOpen. Error code =", GetLastError());
    }
    //---
}

//+------------------------------------------------------------------+
//| Read the XML File                                                |
//+------------------------------------------------------------------+
void xmlRead()
{
    //---
    ResetLastError();
    sData = "";
    ulong pos[];
    int size_;
    Print(INAME + ": Reading XML file.");
    int FileHandle = FileOpen(xmlFileName, FILE_READ | FILE_BIN | FILE_ANSI);
    if (FileHandle != INVALID_HANDLE)
    {
        //--- Receive the file size
        ulong size = FileSize(FileHandle);
        //--- Read data from the file
        while (!FileIsEnding(FileHandle))
            sData += FileReadString(FileHandle, (int)size);
        //--- Close
        FileClose(FileHandle);
        Print(INAME + ": XML file read successfully.");
    }
    //--- Check for errors
    else
        PrintFormat(INAME + ": Failed to open %s file, Error code = %d", xmlFileName, GetLastError());
    Print(INAME + ": Done reading XML.");
    //---
}

//+------------------------------------------------------------------+
//| Check for Update XML                                             |
//+------------------------------------------------------------------+
void xmlUpdate()
{
    Sleep(3000);
    //--- Do not download on Saturday
    if (TimeDayOfWeek(Midnight) == 6)
    {
        Print(INAME + ": Today is Saturday. Skipping XML update.");
        return;
    }
    else
    {
        Print(INAME + ": Checking for XML updates...");
        Print(INAME + ": Deleting old XML file.");
        FileDelete(xmlFileName);
        xmlDownload();
        xmlRead();
        xmlModified = (datetime)FileGetInteger(xmlFileName, FILE_MODIFY_DATE, false);  // Corrected spelling
        PrintFormat(INAME + ": XML updated successfully! Last modified: %s", TimeToString(xmlModified));
    }
    //---
}

//+------------------------------------------------------------------+
//| Converts ff time & date into yyyy.mm.dd hh:mm - by deVries       |
//+------------------------------------------------------------------+
string MakeDateTime(string strDate, string strTime)
{
    //---
    int n1stDash = StringFind(strDate, "-");
    int n2ndDash = StringFind(strDate, "-", n1stDash + 1);

    string strMonth = StringSubstr(strDate, 0, 2);
    string strDay = StringSubstr(strDate, 3, 2);
    string strYear = StringSubstr(strDate, 6, 4);

    string tempStr[];
    StringSplit(strTime, ":", tempStr);
    int nTimeColonPos = StringFind(strTime, ":");
    string strHour = tempStr[0];
    string strMinute = StringSubstr(tempStr[1], 0, 2);
    string strAM_PM = StringSubstr(tempStr[1], 2, 2);

    int nHour24 = StringToInteger(strHour);
    if ((strAM_PM == "pm" || strAM_PM == "PM") && nHour24 != 12)
        nHour24 += 12;
    if ((strAM_PM == "am" || strAM_PM == "AM") && nHour24 == 12)
        nHour24 = 0;
    string strHourPad = "";
    if (nHour24 < 10)
        strHourPad = "0";
    return ((strYear + "." + strMonth + "." + strDay + " " + strHourPad + nHour24 + ":" + strMinute));
    //---
}

//+------------------------------------------------------------------+
//| Convert day of the week to text                                  |
//+------------------------------------------------------------------+
string DayToStr(datetime time)
{
    int ThisDay = TimeDayOfWeek(time);
    string day = "";
    switch (ThisDay)
    {
        case 0:
            day = "Sun";
            break;
        case 1:
            day = "Mon";
            break;
        case 2:
            day = "Tue";
            break;
        case 3:
            day = "Wed";
            break;
        case 4:
            day = "Thu";
            break;
        case 5:
            day = "Fri";
            break;
        case 6:
            day = "Sat";
            break;
    }
    return (day);
}

//+------------------------------------------------------------------+
//| Convert month number to text                                     |
//+------------------------------------------------------------------+
string MonthToStr()
{
    int ThisMonth = Month();
    string month = "";
    switch (ThisMonth)
    {
        case 1:
            month = "Jan";
            break;
        case 2:
            month = "Feb";
            break;
        case 3:
            month = "Mar";
            break;
        case 4:
            month = "Apr";
            break;
        case 5:
            month = "May";
            break;
        case 6:
            month = "Jun";
            break;
        case 7:
            month = "Jul";
            break;
        case 8:
            month = "Aug";
            break;
        case 9:
            month = "Sep";
            break;
        case 10:
            month = "Oct";
            break;
        case 11:
            month = "Nov";
            break;
        case 12:
            month = "Dec";
            break;
    }
    return (month);
}

string nextNews = "...";
int total = 0;

//+------------------------------------------------------------------+
//| Determine Upcoming News Impact                                  |
//+------------------------------------------------------------------+
int UpcomingNewsImpact(string symb, int n)
{
    nextNews = "...";
    string MainSymbol = StringSubstr(symb, 0, 3);
    string SecondSymbol = StringSubstr(symb, 3, 3);
    //---
    if (assignVal)
    {
        //--- Define the XML Tags and Variables
        string sTags[7] = { "<title>", "<country>", "<date><![CDATA[", "<time><![CDATA[", "<impact><![CDATA[", "<forecast><![CDATA[", "<previous><![CDATA[" };
        string eTags[7] = { "</title>", "</country>", "]]></date>", "]]></time>", "]]></impact>", "]]></forecast>", "]]></previous>" };
        int index = 0;
        int next = -1;
        int BoEvent = 0, begin = 0, end = 0;
        string myEvent = "";
        //--- Minutes calculation
        datetime EventTime = 0;
        int EventMinute = 0;
        //--- Loop to parse events from XML
        while (true)
        {
            BoEvent = StringFind(sData, "<event>", BoEvent);
            if (BoEvent == -1)
                break;
            BoEvent += 7;
            next = StringFind(sData, "</event>", BoEvent);
            if (next == -1)
                break;
            myEvent = StringSubstr(sData, BoEvent, next - BoEvent);
            BoEvent = next;
            begin = 0;
            for (int i = 0; i < 7; i++)
            {
                Event[index][i] = "";
                next = StringFind(myEvent, sTags[i], begin);
                //--- If tag not found, skip it
                if (next == -1)
                    continue;
                else
                {
                    //--- Advance past the start tag
                    begin = next + StringLen(sTags[i]);
                    end = StringFind(myEvent, eTags[i], begin);
                    //--- Get data between start and end tag
                    if (end > begin && end != -1)
                        Event[index][i] = StringSubstr(myEvent, begin, end - begin);
                }
            }
            //--- Skip events with tentative time or missing time
            if (Event[index][TIME] == "Tentative" || Event[index][TIME] == "")
                continue;

            //--- Clean up CDATA and other tags
            if (StringFind(Event[index][TITLE], "<![CDATA[") != -1)
                StringReplace(Event[index][TITLE], "<![CDATA[", "");
            if (StringFind(Event[index][TITLE], "]]>") != -1)
                StringReplace(Event[index][TITLE], "]]>", "");
            if (StringFind(Event[index][FORECAST], "&lt;") != -1)
                StringReplace(Event[index][FORECAST], "&lt;", "");
            if (StringFind(Event[index][PREVIOUS], "&lt;") != -1)
                StringReplace(Event[index][PREVIOUS], "&lt;", "");

            //--- Set default values if empty
            if (Event[index][FORECAST] == "")
                Event[index][FORECAST] = "---";
            if (Event[index][PREVIOUS] == "")
                Event[index][PREVIOUS] = "---";

            //--- Convert Event time to MT4 time
            string evD = MakeDateTime(Event[index][DATE], Event[index][TIME]);
            EventTime = StringToTime(evD);
            eTime[index][n] = EventTime - TimeGMTOffset();
            //--- Assign other event details
            eTitle[index][n] = Event[index][TITLE];
            eCountry[index][n] = Event[index][COUNTRY];
            eImpact[index][n] = Event[index][IMPACT];
            eForecast[index][n] = Event[index][FORECAST];
            ePrevious[index][n] = Event[index][PREVIOUS];
            index++;
            //--- Prevent array overflow
            if (index >= 200)
                break;
        }
        total = index;
        assignVal = false; // Reset assignVal after parsing
        Print(INAME + ": Parsed " + IntegerToString(total) + " news events.");
    }

    datetime tn = TimeCurrent();
    for (int qi = 0; qi < total; qi++)
    {
        //--- Check if the news event is relevant to the current symbol
        if (MainSymbol != eCountry[qi][n] && SecondSymbol != eCountry[qi][n])
            continue;

        //--- Draw vertical lines based on impact
        if (news_High && eImpact[qi][n] == "High")
        {
            if (news_High_Line)
                VLineCreate(0, "Tr_VLine" + TimeToString(eTime[qi][n], TIME_DATE | TIME_MINUTES), 0, eTime[qi][n], clrRed, STYLE_SOLID);
        }
        if (news_Medium && eImpact[qi][n] == "Medium")
        {
            if (news_Medium_Line)
                VLineCreate(0, "Tr_VLine" + TimeToString(eTime[qi][n], TIME_DATE | TIME_MINUTES), 0, eTime[qi][n], clrOrange, STYLE_SOLID);
        }
        if (news_Low && eImpact[qi][n] == "Low")
        {
            if (news_Low_Line)
                VLineCreate(0, "Tr_VLine" + TimeToString(eTime[qi][n], TIME_DATE | TIME_MINUTES), 0, eTime[qi][n], clrYellow, STYLE_SOLID);
        }

        //--- Check if current time is within the specified range for each impact level
        if (news_High && eImpact[qi][n] == "High" &&
            eTime[qi][n] < (tn + minAfter * 60) && eTime[qi][n] > (tn - minBefore * 60))
        {
            Print(INAME + ": High impact news detected at " + TimeToString(eTime[qi][n], TIME_DATE | TIME_MINUTES));
            return (1);
        }
        if (news_Medium && eImpact[qi][n] == "Medium" &&
            eTime[qi][n] < (tn + minAfter1 * 60) && eTime[qi][n] > (tn - minBefore1 * 60))
        {
            Print(INAME + ": Medium impact news detected at " + TimeToString(eTime[qi][n], TIME_DATE | TIME_MINUTES));
            return (1);
        }
        if (news_Low && eImpact[qi][n] == "Low" &&
            eTime[qi][n] < (tn + minAfter2 * 60) && eTime[qi][n] > (tn - minBefore2 * 60))
        {
            Print(INAME + ": Low impact news detected at " + TimeToString(eTime[qi][n], TIME_DATE | TIME_MINUTES));
            return (1);
        }
    }
    return (-1);
}

//+------------------------------------------------------------------+
//| Determine if News Should Pause Trading                          |
//+------------------------------------------------------------------+
bool isNewsPause(string Symb, int n)
{
    bool res = (UpcomingNewsImpact(Symb, n) == 1);
    return res;
}

//+------------------------------------------------------------------+
