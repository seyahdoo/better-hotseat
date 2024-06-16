//Variables
bool setupWindowVisible = false;
bool localRecordsWindowVisible = false;
bool inGameControlsVisible = false;
uint players = 2;
uint multiplier = 3;
uint mapNR = 0;
uint shownMapNR = 1;
bool oneShot = false;
array<wstring> Names = {"Red","Green","Blue","Orange","Yellow","Pink","Black","White"};
wstring[] maps;
string recordMap = "";
array<uint> Times = {0,0,0,0,0,0,0,0};
bool changingMap = false;
array<string> rNames;
array<uint> rTimes;
array<string> rTimesString;
array<string> lNames;
array<uint> lTimes;
array<string> lTimesString;
array<uint> lIndices;

UI::Font@ font = null;
UI::Font@ fontLB = null;
UI::Font@ fontStart = null;
uint lastGhosts = 0;
string scriptInput = "";
string scriptOutput = "";
bool is_playing = false;
bool was_ingame = false;

[Setting name="Path to documents folder:"]
string pathToDocuments = "";

//These Settings are just meant to save names across sessions
[Setting name="Horizontal resolution:"]
int winX = 1920;

[Setting name="Vertical resolution:"]
int winY = 1080;

[Setting name="Player 1 name:"]
string player1 = "Red";

[Setting name="Player 2 name:"]
string player2 = "Green";

[Setting name="Player 3 name:"]
string player3 = "Blue";

[Setting name="Player 4 name:"]
string player4 = "Orange";

[Setting name="Player 5 name:"]
string player5 = "Yellow";

[Setting name="Player 6 name:"]
string player6 = "Pink";

[Setting name="Player 7 name:"]
string player7 = "Black";

[Setting name="Player 8 name:"]
string player8 = "White";

void Main() {
	@font = UI::LoadFont("DroidSans.ttf",30);
	@fontLB = UI::LoadFont("DroidSans.ttf",20);
	@fontStart = UI::LoadFont("DroidSans.ttf",51);
	FixFolders();
}

void RenderMenu() {
	if (UI::BeginMenu("Better Hotseat")) {
		if (UI::MenuItem("Setup Window")) {
			loadNames();
			CTrackMania@ app = cast<CTrackMania>(GetApp());
			CGameMatchSettingsManagerScript@ settings = cast<CGameMatchSettingsManagerScript>(app.MenuManager.MenuCustom_CurrentManiaApp.MatchSettingsManager);
			for (uint i = 0; i < settings.MatchSettings[settings.MatchSettings.Length - 1].Playlist.Length; i++) {
				maps.InsertLast(settings.MatchSettings[settings.MatchSettings.Length - 1].Playlist[i].Name);
			}
			setupWindowVisible = !setupWindowVisible;
		}
		if (UI::MenuItem("Local Records")) {
			localRecordsWindowVisible = !localRecordsWindowVisible;
		}
		if (UI::MenuItem("In Game Controls")) {
			inGameControlsVisible = !inGameControlsVisible;
		}
		UI::EndMenu(); 
	}
}

void Render() {
	CTrackMania@ app = cast<CTrackMania>(GetApp());
    if (setupWindowVisible) {
        RenderSetupMenu(app);
    }
	if (app.CurrentPlayground is null || app.CurrentPlayground.Interface is null || not UI::IsGameUIVisible()) {
		return;
	}
	if (localRecordsWindowVisible) {
        RenderLocalRecordsMenu(app);
    }
	if (inGameControlsVisible) {
        RenderInGameControls(app);
    }
	if(app.ManiaPlanetScriptAPI.ActiveContext_InGameMenuDisplayed and is_playing) {
		RenderQuitButtonWarning(app);
	}
}

void RenderSetupMenu(CTrackMania@ app){
	UI::SetNextWindowSize(295, 505);
	UI::SetNextWindowPos(winX - 300,47);
	UI::Begin("Better Hotseat", setupWindowVisible);
	auto playground = app.PlaygroundScript;
	if (playground !is null) {
		UI::PushFont(font);
		UI::Text("\\$F30" + "EXIT MAP FIRST");
		UI::PopFont();
	} else {
		UI::PushFont(fontLB);
		UI::SetNextItemWidth(120);
		players = UI::InputInt("Number of players", players);
		if (players < 2) players = 2;
		if (players > 8) players = 8;
		UI::SetNextItemWidth(120);
		multiplier = UI::InputInt("Time multiplier", multiplier);
		if (multiplier < 1) multiplier = 1;
		
		CGameMatchSettingsManagerScript@ settings = cast<CGameMatchSettingsManagerScript>(app.MenuManager.MenuCustom_CurrentManiaApp.MatchSettingsManager);
		if (settings.MatchSettings[settings.MatchSettings.Length - 1].Playlist.Length != maps.Length) {
			maps = {};
			for (uint i = 0; i < settings.MatchSettings[settings.MatchSettings.Length - 1].Playlist.Length; i++) {
				maps.InsertLast(settings.MatchSettings[settings.MatchSettings.Length - 1].Playlist[i].Name);
			}
		}
		UI::SetNextItemWidth(120);
		shownMapNR = UI::InputInt("Selected Map", shownMapNR);
		if (shownMapNR < 1) shownMapNR = maps.Length;
		if (shownMapNR > maps.Length) shownMapNR = 1;
		mapNR = shownMapNR-1;
		
		oneShot = UI::Checkbox("Oneshot gamemode", oneShot);
		
		UI::PopFont();
		for (uint i = 0; i < Names.Length; i++) {
			UI::PushFont(fontLB);
			UI::SetNextItemWidth(120);
			if (i < players) {	
				Names[i] = UI::InputText("\\$3F3" + "Player " + (i+1), Names[i]);
			} else { 
				Names[i] = UI::InputText("\\$F30" + "Player " + (i+1), Names[i]);
			}
			UI::PopFont();
			ButtonControl(i);
		}
		saveNames();
	}
	StartHotseatButton(app);
	UI::End();
}

void StartHotseatButton(CTrackMania@ app){
	UI::PushFont(fontStart);
	if (Permissions::PlayHotSeat() && Permissions::PlayLocalMap() && (UI::Button("Start Hotseat") or (changingMap && app.ManiaTitleControlScriptAPI.IsReady))) {
		if (maps.Length == 0) {
			print("you have to select maps in the local network tab before starting! See Plugin description");
			return;
		}
		is_playing = true;
		changingMap = false;
		if (oneShot) multiplier=0;
		IO::File file(scriptOutput + "\\Hotseat.Script.txt");
		IO::FileSource file2("GhostHotseatTest.Script.txt");
		file.Open(IO::FileMode::Write);
		// REMOVE FROM OP FILE
		//file2.Open(IO::FileMode::Read);
		uint i = 0;
		while (!file2.EOF()) {
			string line = file2.ReadLine();
			if (line.StartsWith("#Setting")) {
				if (i == 0) line = line.Replace("xxxxx", "" + multiplier);
				if (i == 1) line = line.Replace("xxxxx", "" + players);
				for (uint k = 0; k < 8; k++) {
					if (i == 2+k) line = line.Replace("xxxxx", Names[k]);
				}
				i += 1;
			}
			file.Write(line + "\n");
		}
		file.Close();
		// REMOVE FROM OP FILE
		//file2.Close();
		CGameManiaTitleControlScriptAPI@ controlScript = cast<CGameManiaTitleControlScriptAPI>(app.ManiaTitleControlScriptAPI);
		print(mapNR + " " + maps.Length);
		controlScript.PlayMap(maps[mapNR],"Modes\\TrackMania\\Hotseat.Script.txt","");
		recordMap = maps[mapNR];
		loadRecords();
		lTimes = rTimes;
		lNames = rNames;
		lTimesString  = rTimesString;
		shownMapNR += 1;
		print(mapNR);
		setupWindowVisible = false;
		localRecordsWindowVisible = true;
		inGameControlsVisible = true;
	} else if ((not Permissions::PlayHotSeat()) or (not Permissions::PlayLocalMap())) {
		print("Insufficient rights!");
	}
	UI::PopFont();
}

void RenderLocalRecordsMenu(CTrackMania@ app){
	int windowWidth = 300;
	int windowHeight = 430;
	UI::SetNextWindowSize(windowWidth, windowHeight);
	UI::SetNextWindowPos(Draw::GetWidth() - windowWidth, 0);
	UI::PushStyleColor(UI::Col::WindowBg, UI::InputColor4("local records background", vec4(0,0,0,0)));
	int windowparams = UI::WindowFlags::NoTitleBar | UI::WindowFlags::NoResize | UI::WindowFlags::NoCollapse;
	UI::Begin("Better Hotseat - Local Records", localRecordsWindowVisible, windowparams);
	
	auto playground = app.PlaygroundScript;
	
	// looking for new records/improvements
	if(playground !is null) {
		was_ingame = true;
		auto manager = playground.DataFileMgr;
		if (manager is null) return;
		auto ghosts = manager.Ghosts;
		uint ghostslength = ghosts.Length;
		if (ghostslength != lastGhosts) {
			lastGhosts = ghostslength;
			// A new time was driven
			bool oneUpdated = false;
			for (uint k = 0; k < ghostslength; k++) {
				for (uint j = 0; j < players; j++) {
					if (Names[j].Contains(ghosts[k].Nickname) && (Times[j] == 0 || Times[j] > ghosts[k].Result.Time)) {
						Times[j] = ghosts[k].Result.Time;
					}
				}
			}
			UpdateLocal();
			saveRecords();
		}
		
	}
	
	uint top = 10;
	if (lTimes.Length < top) top = lTimes.Length;
	for (uint k = 0; k<top; k++) {
		UI::PushFont(font);
		UI::Text(lTimesString[k] + " - " + lNames[k]);
		UI::PopFont();
	}
	UI::End();
	UI::PopStyleColor();
}

void RenderInGameControls(CTrackMania@ app){
	int windowWidth = 335;
	int windowHeight = 40;
	UI::SetNextWindowSize(windowWidth, windowHeight);
	UI::SetNextWindowPos(Draw::GetWidth() - windowWidth, Draw::GetHeight() - windowHeight);
	int windowparams = UI::WindowFlags::NoTitleBar | UI::WindowFlags::NoResize | UI::WindowFlags::NoCollapse | UI::WindowFlags::NoScrollbar;
	UI::Begin("InGameControls", inGameControlsVisible, windowparams);
	UI::PushFont(fontLB);
	if ((not app.ManiaPlanetScriptAPI.ActiveContext_InGameMenuDisplayed) and UI::Button("Next Map")) {
		localRecordsWindowVisible = !localRecordsWindowVisible;
		setupWindowVisible = !setupWindowVisible;
		app.BackToMainMenu();
		changingMap = true;
	}
	UI::SameLine();
	if ((not app.ManiaPlanetScriptAPI.ActiveContext_InGameMenuDisplayed) and UI::Button("Restart Current Map")) {
		shownMapNR -= 1;
		localRecordsWindowVisible = !localRecordsWindowVisible;
		setupWindowVisible = !setupWindowVisible;
		app.BackToMainMenu();
		changingMap = true;
	}
	UI::SameLine();
	if ((not app.ManiaPlanetScriptAPI.ActiveContext_InGameMenuDisplayed) and UI::Button("Quit")) {
		localRecordsWindowVisible = !localRecordsWindowVisible;
		setupWindowVisible = !setupWindowVisible;
		app.BackToMainMenu();
		is_playing = false;
	}
	UI::PopFont();
	UI::End();
}

void RenderQuitButtonWarning(CTrackMania@ app){
	UI::SetNextWindowSize(800, 300);
	UI::SetNextWindowPos(winX/2 - 400,winY/2);
	int windowparams = UI::WindowFlags::NoTitleBar | UI::WindowFlags::NoResize | UI::WindowFlags::NoCollapse;
	UI::Begin("DontLeave", windowparams);
	UI::PushFont(fontLB);
	UI::Text("\\$F30 Restart or Quit through the provided buttons on the bottom right, Leave this menu first");
	UI::PopFont();
	UI::End();
}

void ButtonControl(uint i) {
	UI::PushID("But" + i);
	UI::SameLine();
	uint s1 = i;
	if (UI::Button("")) {
		uint s2 = s1-1;
		if (s1 == 0) s2 = 7;
		//Now we switch the two values
		string temp = Names[s1];
		Names[s1] = Names[s2];
		Names[s2] = temp;
	}
	UI::SameLine();
	if (UI::Button("")) {
		uint s2 = s1+1;
		if (s2 > 7) s2 = 0;
		//Now we switch the two values
		string temp = Names[s1];
		Names[s1] = Names[s2];
		Names[s2] = temp;
	}
	
	UI::PopID();
	
	
}

void loadRecords() {
	rNames = {};
	rTimes = {};
	rTimesString = {};
	
	string[] splitline = recordMap.Split("\\");
	string filename = scriptOutput + "\\Records\\" + splitline[splitline.Length-1].Split(".")[0] + ".txt";
	print("Loading records from: " + filename);
	if (IO::FileExists(filename)) {
		IO::File recs(filename);
		recs.Open(IO::FileMode::Read);
		
		//IO::File recs = IO::FromStorage("Records\\" + splitline[splitline.Length-1].Split(".")[0] + ".txt", IO::FileMode::Read);
		
		//First we will read all entries in the file
		while (!recs.EOF()) {
			string line = recs.ReadLine();
			array<string> splitrline = line.Split(" - ");
			rNames.InsertLast(splitrline[0]);
			rTimes.InsertLast(Text::ParseInt(splitrline[1]));
			rTimesString.InsertLast(TimeRepresentation(splitrline[1]));
		}
		recs.Close();
	}
	
	
}

void saveRecords() {
	print(recordMap);
	string[] splitline = recordMap.Split("\\");
	string filename = scriptOutput + "\\Records\\" + splitline[splitline.Length-1].Split(".")[0] + ".txt";
	print("Saving records to file: " + filename);
	IO::File recs(filename);
	recs.Open(IO::FileMode::Write);
	//IO::File recs = IO::FromStorage("Records\\" + splitline[splitline.Length-1].Split(".")[0] + ".txt", IO::FileMode::Read);
	for (uint j = 0; j < lTimes.Length; j++) {
		recs.Write(lNames[j] + " - " + lTimes[j] + "\n");
		
	}
	recs.Close();
	Times = {0,0,0,0,0,0,0,0};
}

void AddNewIndex(uint ind) {
	if (lIndices.Length > 0) {
		for (uint i = 0; i < lIndices.Length; i++) {
			if (lIndices[i] >= ind) lIndices[i] += 1;
		}
	}
	lIndices.InsertLast(ind);
}

void UpdateLocal() {
	lIndices = {};
	lTimes = rTimes;
	lNames = rNames;
	lTimesString  = rTimesString;
	for (uint j = 0; j < players; j++) {
		if (Times[j] > 0) {
			bool found = false;
			uint i = 0;
			while (!found) {
				if (i == lTimes.Length) {
					found = true;
					lTimes.InsertLast(Times[j]);
					lNames.InsertLast(Names[j]);
					lTimesString.InsertLast(TimeRepresentation("" + Times[j]));
					AddNewIndex(i);
				} else {
					if (lTimes[i] > Times[j]) {
						found = true;
						lTimes.InsertAt(i, Times[j]);
						lNames.InsertAt(i, Names[j]);
						lTimesString.InsertAt(i, TimeRepresentation("" + Times[j]));
						AddNewIndex(i);
					}
				}
				i += 1;
			}
		}
	}
	
}

void UpdateScores() {
	// Now we add our times to the complete collection of times
	for (uint j = 0; j < players; j++) {
		if (Times[j] > 0) {
			bool found = false;
			uint i = 0;
			while (!found) {
				if (i == rTimes.Length) {
					found = true;
					rTimes.InsertLast(Times[j]);
					rNames.InsertLast(Names[j]);
					rTimesString.InsertLast(TimeRepresentation("" + Times[j]));
				} else {
					if (rTimes[i] > Times[j]) {
						found = true;
						rTimes.InsertAt(i, Times[j]);
						rNames.InsertAt(i, Names[j]);
						rTimesString.InsertAt(i, TimeRepresentation("" + Times[j]));
					}
				}
				i += 1;
			}
			
		}
	}
	
}

void restartCurrentMap() {

}


// Method for converting integer time representation to human readable format
string TimeRepresentation(string sTime) {
    int iTime = Text::ParseInt(sTime);
    int copyTime = iTime;
    int ms = copyTime % 1000;
    copyTime = (copyTime - ms) / 1000;
    string output = Time::FormatString("%M:%S", copyTime) + '.';
    if (ms < 10) {
        output = output + "00" + ms;
    } else if (ms < 100) {
        output = output + '0' + ms;
    } else {
        output = output + ms;
    }
    return (output);
}

void FixFolders() {
	string pathToDoc = "";
	string[] splitline = IO::FromDataFolder("").Split("/");
	scriptInput = splitline[0];
	if (pathToDocuments == "" or not IO::FolderExists(pathToDocuments)) {
		if (IO::FolderExists(splitline[0] + "\\Documents\\Trackmania2020")) {
			pathToDoc = splitline[0] + "\\Documents\\Trackmania2020";
		} else if (IO::FolderExists(splitline[0] + "\\Documents\\Trackmania")) {
			pathToDoc = splitline[0] + "\\Documents\\Trackmania";
		} else if (IO::FolderExists(splitline[0] + "\\OneDrive\\Documents\\Trackmania2020")) {
			pathToDoc = splitline[0] + "\\OneDrive\\Documents\\Trackmania2020";
		} else if (IO::FolderExists(splitline[0] + "\\OneDrive\\Documents\\Trackmania")) {
			pathToDoc = splitline[0] + "\\OneDrive\\Documents\\Trackmania";
		} else {
			print("ERROR: Documents folder where trackmania data is located could not be found, please manually fill this in in Openplanets settings.");
		}
		pathToDocuments = pathToDoc;
	} else {
		pathToDoc = pathToDocuments;
	}
	
	
	pathToDoc += "\\Scripts";
	if (!IO::FolderExists(pathToDoc)) {
		IO::CreateFolder(pathToDoc);
	}
	
	pathToDoc += "\\Modes";
	if (!IO::FolderExists(pathToDoc)) {
		IO::CreateFolder(pathToDoc);
	}
	
	pathToDoc += "\\Trackmania";
	if (!IO::FolderExists(pathToDoc)) {
		IO::CreateFolder(pathToDoc);
	}
	scriptOutput = pathToDoc;
	
	if (!IO::FolderExists(pathToDoc + "\\Records")) {
		IO::CreateFolder(pathToDoc + "\\Records");
	}
	
}

void OnSettingsLoad(Settings::Section& section) {
	loadNames();
}

void OnSettingsSave(Settings::Section& section) {
	saveNames();
}

void loadNames() {
	Names[0] = player1;
	Names[1] = player2;
	Names[2] = player3;
	Names[3] = player4;
	Names[4] = player5;
	Names[5] = player6;
	Names[6] = player7;
	Names[7] = player8;
}

void saveNames() {
	player1 = Names[0];
	player2 = Names[1];
	player3 = Names[2];
	player4 = Names[3];
	player5 = Names[4];
	player6 = Names[5];
	player7 = Names[6];
	player8 = Names[7];
}