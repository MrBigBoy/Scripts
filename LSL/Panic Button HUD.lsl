float SCAN_RANGE = 20.0;
float SCAN_INTERVAL = 10.0;
float WB_DELAY = 600.0;

vector COLOR_RED = <1.0,0.0,0.0>;
vector COLOR_GREEN = <0.0,1.0,0.0>;

list greeted = [];
list nearbyKeys = [];
list nearbyNames = [];

list lastSeenKeys = [];
list lastSeenTimes = [];

string currentRegion = "";

integer listenHandle;
integer lastTouchTime = 0;

// ----------------------------
// Replace helper
// ----------------------------
string replaceAll(string src, string from, string to)
{
    integer pos = llSubStringIndex(src, from);

    while(pos != -1)
    {
        src = llDeleteSubString(src, pos, pos + llStringLength(from) - 1);
        src = llInsertString(src, pos, to);
        pos = llSubStringIndex(src, from);
    }

    return src;
}

// ----------------------------
// Normalize fancy unicode
// ----------------------------
string normalizeFancy(string s)
{
    s = replaceAll(s,"ℳ","M");
    s = replaceAll(s,"ᾋ","A");
    s = replaceAll(s,"α","a");
    s = replaceAll(s,"г","r");
    s = replaceAll(s,"ø","o");
    s = replaceAll(s,"ς","c");
    s = replaceAll(s,"ɛ","e");
    s = replaceAll(s,"η","n");
    s = replaceAll(s,"乇","E");
    s = replaceAll(s,"ℓ","l");
    s = replaceAll(s,"乃","B");
    s = replaceAll(s,"ş","s");

    return s;
}

// ----------------------------
// Keep only valid characters
// ----------------------------
string cleanName(string name)
{
    integer i = 0;
    integer len = llStringLength(name);

    string result = "";
    integer hasLatin = FALSE;

    while(i < len)
    {
        string ch = llGetSubString(name,i,i);
        integer code = llOrd(name,i);

        // A-Z
        if(code >= 65 && code <= 90)
        {
            result += ch;
            hasLatin = TRUE;
        }
        // a-z
        else if(code >= 97 && code <= 122)
        {
            result += ch;
            hasLatin = TRUE;
        }
        // accented Latin letters
        else if(code >= 192 && code <= 591)
        {
            result += ch;
            hasLatin = TRUE;
        }
        // allow hyphen
        else if(ch == "-")
        {
            result += ch;
        }
        // allow apostrophe
        else if(ch == "'")
        {
            result += ch;
        }

        ++i;
    }

    if(!hasLatin)
    {
        return "";
    }

    return result;
}

// ----------------------------
// Capitalize
// ----------------------------
string autoCapitalize(string name)
{
    if(llStringLength(name) == 0) return name;

    string first = llToUpper(llGetSubString(name,0,0));
    string rest = llToLower(llGetSubString(name,1,-1));

    return first + rest;
}

// ----------------------------
// Extract first name
// ----------------------------
string extractFirstName(string raw)
{
    raw = normalizeFancy(raw);

    list parts = llParseString2List(raw, [" ", "."], []);

    integer i = 0;
    integer count = llGetListLength(parts);

    while(i < count)
    {
        string part = llList2String(parts,i);
        part = cleanName(part);

        string lower = llToLower(part);

        if(lower != "mr" &&
           lower != "mrs" &&
           lower != "sir" &&
           part != "")
        {
            // ensure the name contains at least ONE real letter
            integer j = 0;
            integer len = llStringLength(part);
            integer hasLetter = FALSE;

            while(j < len)
            {
                integer code = llOrd(part,j);

                if((code >= 65 && code <= 90) || (code >= 97 && code <= 122) || code >= 192)
                {
                    hasLetter = TRUE;
                }

                ++j;
            }

            if(hasLetter)
            {
                return autoCapitalize(part);
            }
        }

        ++i;
    }

    return "";
}

// ----------------------------
// Get display name safely
// ----------------------------
string getDisplayNameSafe(key id)
{
    string name = llGetDisplayName(id);

    string first = extractFirstName(name);

    if(first == "")
    {
        name = llKey2Name(id);
        first = extractFirstName(name);
    }

    return first;
}

// ----------------------------
// Build greeting
// ----------------------------
string buildHi(list names)
{
    integer count = llGetListLength(names);

    if(count == 0) return "";
    if(count == 1) return "Hi " + llList2String(names,0) + ".";
    if(count == 2) return "Hi " + llList2String(names,0) + " and " + llList2String(names,1) + ".";

    string result = "Hi ";

    integer i = 0;

    while(i < count - 1)
    {
        result += llList2String(names,i);

        if(i < count - 2)
        {
            result += ", ";
        }

        ++i;
    }

    result += " and " + llList2String(names,count - 1) + ".";

    return result;
}

// ----------------------------
// Display update
// ----------------------------
updateDisplay()
{
    integer total = llGetListLength(nearbyKeys);
    integer ungreeted = 0;

    integer i = 0;

    while(i < total)
    {
        key id = llList2Key(nearbyKeys,i);

        if(llListFindList(greeted,[id]) == -1)
        {
            ++ungreeted;
        }

        ++i;
    }

    string displayText;
    vector textColor = <1,1,1>;

    if(total == 0)
    {
        llSetColor(COLOR_GREEN, ALL_SIDES);
        displayText = "No one nearby";
    }
    else if(ungreeted > 0)
    {
        llSetColor(COLOR_RED, ALL_SIDES);
        displayText = (string)ungreeted + " to greet";
    }
    else
    {
        llSetColor(COLOR_GREEN, ALL_SIDES);
        displayText = "All greeted ✔";
    }

    llSetText(displayText,textColor,1.0);
}

// ----------------------------
// MAIN
// ----------------------------
default
{
    state_entry()
    {
        currentRegion = llGetRegionName();

        llSetColor(COLOR_GREEN, ALL_SIDES);
        llSetText("Scanning...",<1,1,1>,1.0);

        llSensorRepeat("", NULL_KEY, AGENT, SCAN_RANGE, PI, SCAN_INTERVAL);

        listenHandle = llListen(0, "", llGetOwner(), "");

        updateDisplay();
    }

    sensor(integer total_number)
    {
        list newKeys = [];
        list newNames = [];

        integer i = 0;
        float now = llGetUnixTime();

        while(i < total_number)
        {
            key id = llDetectedKey(i);

            if(id != llGetOwner())
            {
                string display = getDisplayNameSafe(id);

                newKeys += id;
                newNames += display;

                integer idx = llListFindList(lastSeenKeys,[id]);

                if(idx == -1)
                {
                    lastSeenKeys += id;
                    lastSeenTimes += now;
                }
                else
                {
                    float last = llList2Float(lastSeenTimes,idx);

                    if(now - last > WB_DELAY)
                    {
                        llOwnerSay("Wb " + display + ".");
                    }

                    lastSeenTimes = llListReplaceList(lastSeenTimes,[now],idx,idx);
                }
            }

            ++i;
        }

        nearbyKeys = newKeys;
        nearbyNames = newNames;

        updateDisplay();
    }

    no_sensor()
    {
        nearbyKeys = [];
        nearbyNames = [];

        updateDisplay();
    }

    touch_start(integer total_number)
    {
        integer now = llGetUnixTime();

        if(now - lastTouchTime <= 5)
        {
            greeted = nearbyKeys;
            llOwnerSay("Everyone marked as greeted.");
            updateDisplay();
            lastTouchTime = 0;
            return;
        }

        lastTouchTime = now;

        list hiList = [];

        integer i = 0;

        while(i < llGetListLength(nearbyKeys))
        {
            key id = llList2Key(nearbyKeys,i);

            if(llListFindList(greeted,[id]) == -1)
            {
                hiList += llList2String(nearbyNames,i);
            }

            ++i;
        }

        string sentence = buildHi(hiList);

        if(sentence != "")
        {
            llOwnerSay(sentence);
        }
        else
        {
            llOwnerSay("Everyone nearby has already been greeted.");
        }
    }

    listen(integer channel, string name, key id, string message)
    {
        string lower = llToLower(message);

        if(llSubStringIndex(lower,"hi ") == 0 ||
           llSubStringIndex(lower,"hello ") == 0 ||
           llSubStringIndex(lower,"wb ") == 0)
        {
            integer i = 0;

            while(i < llGetListLength(nearbyKeys))
            {
                key avatarKey = llList2Key(nearbyKeys,i);
                string avatarName = llList2String(nearbyNames,i);

                if(llSubStringIndex(lower,llToLower(avatarName)) != -1)
                {
                    if(llListFindList(greeted,[avatarKey]) == -1)
                    {
                        greeted += avatarKey;
                    }
                }

                ++i;
            }

            updateDisplay();
        }
    }

    changed(integer change)
    {
        if(change & CHANGED_REGION)
        {
            greeted = [];
            nearbyKeys = [];
            nearbyNames = [];
            lastSeenKeys = [];
            lastSeenTimes = [];

            currentRegion = llGetRegionName();

            llOwnerSay("Region changed - greeting list reset.");

            updateDisplay();
        }
    }
}