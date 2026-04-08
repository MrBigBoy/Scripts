float SCAN_INTERVAL = 2.0;
float WB_DELAY = 600.0;
float GREET_RANGE = 20.0;

vector COLOR_RED = <1.0,0.0,0.0>;
vector COLOR_GREEN = <0.0,1.0,0.0>;
vector COLOR_YELLOW = <1.0,1.0,0.0>;

list greeted = [];
list nearbyKeys = [];
list nearbyNames = [];

list knownKeys = [];
list knownNames = [];

list seenKeys = [];
list seenTimes = [];

list previousKeys = [];

string currentRegion = "";
integer listenHandle = 0;
integer lastTouchTime = 0;
integer ready = FALSE;
integer hasScannedOnce = FALSE;

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
    s = replaceAll(s,"ل","J");
    s = replaceAll(s,"ε","e");
    s = replaceAll(s,"ɳ","n");
    s = replaceAll(s,"Ḻ","L");
    s = replaceAll(s,"Ѻ","O");
    s = replaceAll(s,"Ḱ","K");
    s = replaceAll(s,"Ї","I");

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
    integer hasLetter = FALSE;

    while(i < len)
    {
        string ch = llGetSubString(name, i, i);
        integer code = llOrd(name, i);

        if((code >= 65 && code <= 90) || (code >= 97 && code <= 122))
        {
            result += ch;
            hasLetter = TRUE;
        }
        else if(code >= 192 && code <= 591)
        {
            result += ch;
            hasLetter = TRUE;
        }
        else if(code >= 880 && code <= 1279)
        {
            result += ch;
            hasLetter = TRUE;
        }
        else if(ch == "-" || ch == "'")
        {
            result += ch;
        }

        ++i;
    }

    if(!hasLetter) return "";    
    return result;
}

// ----------------------------
// Capitalize
// ----------------------------
string autoCapitalize(string name)
{
    if(llStringLength(name) == 0) return name;

    string first = llToUpper(llGetSubString(name, 0, 0));
    string rest = llToLower(llGetSubString(name, 1, -1));

    string name = first+rest;
    
    if(name == "Aknightz") {
        name = "AK";
    }
    return name;
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
        string part = llList2String(parts, i);
        part = cleanName(part);

        if(part != "")
        {
            string lower = llToLower(part);

            if(lower != "mr" &&
               lower != "mrs" &&
               lower != "sir")
            {
                return autoCapitalize(part);
            }
        }

        ++i;
    }

    return "";
}

// ----------------------------
// Cache helpers
// ----------------------------
string getCachedName(key id)
{
    integer idx = llListFindList(knownKeys, [id]);

    if(idx != -1)
    {
        return llList2String(knownNames, idx);
    }

    return "";
}

string cacheNameForKey(key id)
{
    string name = llGetDisplayName(id);
    name = extractFirstName(name);

    if(name == "")
    {
        name = llKey2Name(id);
        name = extractFirstName(name);
    }

    integer idx = llListFindList(knownKeys, [id]);

    if(idx == -1)
    {
        knownKeys += [id];
        knownNames += [name];
    }
    else
    {
        knownNames = llListReplaceList(knownNames, [name], idx, idx);
    }

    return name;
}

string getNameForKey(key id)
{
    string name = getCachedName(id);

    if(name == "")
    {
        name = cacheNameForKey(id);
    }

    return name;
}

integer isGreeted(key id)
{
    if(llListFindList(greeted, [id]) == -1)
    {
        return FALSE;
    }
    return TRUE;
}

markGreeted(key id)
{
    if(!isGreeted(id))
    {
        greeted += [id];
    }
}

integer isKeyInList(list src, key id)
{
    if(llListFindList(src, [id]) == -1)
    {
        return FALSE;
    }
    return TRUE;
}

// ----------------------------
// Build greeting sentence
// ----------------------------
string buildHi(list names)
{
    integer count = llGetListLength(names);

    if(count == 0) return "";
    if(count == 1) return "Hi " + llList2String(names, 0) + ".";
    if(count == 2) return "Hi " + llList2String(names, 0) + " and " + llList2String(names, 1) + ".";

    string result = "Hi ";
    integer i = 0;

    while(i < count - 1)
    {
        result += llList2String(names, i);

        if(i < count - 2)
        {
            result += ", ";
        }

        ++i;
    }

    result += " and " + llList2String(names, count - 1) + ".";

    return result;
}

// ----------------------------
// Speak greetings for ungreeted nearby avatars
// ----------------------------
greetPeople()
{
    list hiList = [];
    integer i = 0;
    integer count = llGetListLength(nearbyKeys);

    while(i < count)
    {
        key id = llList2Key(nearbyKeys, i);

        if(!isGreeted(id))
        {
            string n = llList2String(nearbyNames, i);

            if(n != "")
            {
                if(llListFindList(hiList, [n]) == -1)
                {
                    hiList += [n];
                }
            }
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

// ----------------------------
// Display update
// ----------------------------
updateDisplay()
{
    integer total = llGetListLength(nearbyKeys);
    integer ungreeted = 0;
    integer i = 0;

    if(!hasScannedOnce)
    {
        llSetColor(COLOR_YELLOW, ALL_SIDES);
        llSetText("Scanning...", <1,1,1>, 1.0);
        return;
    }

    while(i < total)
    {
        key id = llList2Key(nearbyKeys, i);

        if(!isGreeted(id))
        {
            ++ungreeted;
        }

        ++i;
    }

    string displayText;

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

    llSetText(displayText, <1,1,1>, 1.0);
}

// ----------------------------
// MAIN
// ----------------------------
default
{
    state_entry()
    {
        greeted = [];
        nearbyKeys = [];
        nearbyNames = [];
        knownKeys = [];
        knownNames = [];
        seenKeys = [];
        seenTimes = [];
        previousKeys = [];
        ready = FALSE;
        hasScannedOnce = FALSE;

        currentRegion = llGetRegionName();

        llSetColor(COLOR_YELLOW, ALL_SIDES);
        llSetText("Scanning...", <1,1,1>, 1.0);

        if(listenHandle)
        {
            llListenRemove(listenHandle);
        }

        listenHandle = llListen(0, "", llGetOwner(), "");

        llSetTimerEvent(SCAN_INTERVAL);
    }

    timer()
    {
        list parcelAgents = llGetAgentList(AGENT_LIST_PARCEL, []);
        list newKeys = [];
        list newNames = [];
        integer foundNew = FALSE;

        vector myPos = llGetPos();
        integer i = 0;
        integer count = llGetListLength(parcelAgents);
        float now = llGetUnixTime();

        while(i < count)
        {
            key id = llList2Key(parcelAgents, i);

            if(id != llGetOwner())
            {
                list details = llGetObjectDetails(id, [OBJECT_POS]);

                if(llGetListLength(details) > 0)
                {
                    vector pos = llList2Vector(details, 0);
                    float dist = llVecDist(myPos, pos);

                    if(dist <= GREET_RANGE)
                    {
                        string name = getNameForKey(id);

                        newKeys += [id];
                        newNames += [name];

                        integer seenIdx = llListFindList(seenKeys, [id]);

                        if(seenIdx == -1)
                        {
                            seenKeys += [id];
                            seenTimes += [now];

                            if(name != "")
                            {
                                llOwnerSay("New: " + name);
                                foundNew = TRUE;
                            }
                        }
                        else
                        {
                            float last = llList2Float(seenTimes, seenIdx);

                            if((now - last) > WB_DELAY)
                            {
                                if(name != "")
                                {
                                    llOwnerSay("Wb " + name + ".");
                                }
                            }

                            seenTimes = llListReplaceList(seenTimes, [now], seenIdx, seenIdx);
                        }
                    }
                }
            }

            ++i;
        }

        integer j = 0;
        integer prevCount = llGetListLength(previousKeys);

        while(j < prevCount)
        {
            key oldID = llList2Key(previousKeys, j);

            if(!isKeyInList(newKeys, oldID))
            {
                integer idx = llListFindList(knownKeys, [oldID]);

                if(idx != -1)
                {
                    string oldName = llList2String(knownNames, idx);

                    if(oldName != "")
                    {
                        llOwnerSay(oldName + " left.");
                    }
                }
            }

            ++j;
        }

        previousKeys = newKeys;
        nearbyKeys = newKeys;
        nearbyNames = newNames;

        hasScannedOnce = TRUE;

        if(foundNew)
        {
            greetPeople();
        }

        if(!ready)
        {
            ready = TRUE;
        }

        updateDisplay();
    }

    touch_start(integer total_number)
    {
        if(!ready)
        {
            llOwnerSay("Still scanning...");
            return;
        }

        integer now = llGetUnixTime();

        if(now - lastTouchTime <= 5)
        {
            integer i = 0;
            integer count = llGetListLength(nearbyKeys);

            while(i < count)
            {
                key id = llList2Key(nearbyKeys, i);
                markGreeted(id);
                ++i;
            }

            llOwnerSay("Everyone marked as greeted.");
            updateDisplay();
            lastTouchTime = 0;
        }
        else
        {
            lastTouchTime = now;
            greetPeople();
        }
    }

    listen(integer channel, string name, key id, string message)
    {
        if(!ready)
        {
            return;
        }

        if(id != llGetOwner())
        {
            return;
        }

        string lower = llToLower(message);

        if(llSubStringIndex(lower, "hi ") == 0 ||
           llSubStringIndex(lower, "hello ") == 0 ||
           llSubStringIndex(lower, "wb ") == 0)
        {
            integer i = 0;
            integer count = llGetListLength(nearbyKeys);

            while(i < count)
            {
                key avatarKey = llList2Key(nearbyKeys, i);
                string avatarName = llList2String(nearbyNames, i);

                if(avatarName != "")
                {
                    if(llSubStringIndex(lower, llToLower(avatarName)) != -1)
                    {
                        markGreeted(avatarKey);
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
            llOwnerSay("Region changed - greeting list reset.");
            llResetScript();
        }

        if(change & CHANGED_OWNER)
        {
            llResetScript();
        }
    }
}