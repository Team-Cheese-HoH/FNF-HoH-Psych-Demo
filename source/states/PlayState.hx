package states;

// If you want to add your stage to the game, copy states/stages/Template.hx,
// and put your stage code there, then, on PlayState, search for
// "switch (curStage)", and add your stage to that list.
// If you want to code Events, you can either code it on a Stage file or on PlayState, if you're doing the latter, search for:
// "function eventPushed" - Only called *one time* when the game loads, use it for precaching events that use the same assets, no matter the values
// "function eventPushedUnique" - Called one time per event, use it for precaching events that uses different assets based on its values
// "function eventEarlyTrigger" - Used for making your event start a few MILLISECONDS earlier
// "function triggerEvent" - Called when the song hits your event's timestamp, this is probably what you were looking for
import ComboSprite;
#if ACHIEVEMENTS_ALLOWED
import backend.Achievements;
#end
import backend.Highscore;
import backend.ObjectBlendMode;
import backend.Rating;
import backend.Section;
import backend.Song;
import backend.StageData;
import backend.WeekData;
import cutscenes.CutsceneHandler;
import cutscenes.DialogueBoxPsych;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.animation.FlxAnimationController;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxPoint;
import flixel.util.FlxSave;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import lime.utils.Assets;
import objects.*;
import objects.Note.EventNote;
import objects.Soulmeter;
import objects.Timebar;
import openfl.display.BlendMode;
import openfl.events.KeyboardEvent;
import openfl.utils.Assets as OpenFlAssets;
import overworld.*;
import shaders.Shaders;
import states.FreeplayState;
import states.editors.CharacterEditorState;
import states.editors.ChartingState;
import states.stages.objects.*;
import substates.GameOverSubstate;
import substates.PauseSubState;
import substates.SillySub;
import tjson.TJSON as Json;
#if !flash
import flixel.addons.display.FlxRuntimeShader;
import openfl.filters.ShaderFilter;
#end
#if VIDEOS_ALLOWED
import hxvlc.flixel.FlxVideoSprite;
#end
#if LUA_ALLOWED
import psychlua.*;
import psychlua.FunkinLua;
import psychlua.HScript;
#else
import psychlua.LuaUtils;
#end
#if (SScript >= "3.0.0")
import tea.SScript;
#end
import filters.AudioEffects;

class PlayState extends MusicBeatState {
	public inline static final STRUM_X = 42;
	public inline static final STRUM_X_MIDDLESCROLL = -278;

	public static var ratingStuff:Array<Dynamic> = [
		['You Suck!', 0.2], // From 0% to 19%
		['Shit', 0.4], // From 20% to 39%
		['Bad', 0.5], // From 40% to 49%
		['Bruh', 0.6], // From 50% to 59%
		['Meh', 0.69], // From 60% to 68%
		['Nice', 0.7], // 69%
		['Good', 0.8], // From 70% to 79%
		['Great', 0.9], // From 80% to 89%
		['Sick!', 1], // From 90% to 99%
		['Perfect!!', 1] // The value on this one isn't used actually, since Perfect is always "1"
	];

	// event variables
	private var isCameraOnForcedPos:Bool = false;

	public var boyfriendMap:Map<String, Character> = new Map<String, Character>();
	public var dadMap:Map<String, Character> = new Map<String, Character>();
	public var gfMap:Map<String, Character> = new Map<String, Character>();
	public var variables:Map<String, Dynamic> = new Map<String, Dynamic>();

	#if HSCRIPT_ALLOWED
	public var hscriptArray:Array<HScript> = [];
	#end

	#if LUA_ALLOWED
	public var modchartTweens:Map<String, FlxTween> = new Map<String, FlxTween>();
	public var modchartSprites:Map<String, ModchartSprite> = new Map<String, ModchartSprite>();
	public var modchartTimers:Map<String, FlxTimer> = new Map<String, FlxTimer>();
	public var modchartSounds:Map<String, FlxSound> = new Map<String, FlxSound>();
	public var modchartTexts:Map<String, FlxText> = new Map<String, FlxText>();
	public var modchartSaves:Map<String, FlxSave> = new Map<String, FlxSave>();
	#end

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var songSpeedTween:FlxTween;
	public var songSpeed(default, set):Float = 1;
	public var songSpeedType:String = "multiplicative";
	public var noteKillOffset:Float = 350;

	public var playbackRate(default, set):Float = 1;

	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;

	public var curStage:String = '';
	public var stageUI:String = "normal";

	public static var SONG:SwagSong = null;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;

	public var spawnTime:Float = 2000;

	public var vocals:FlxSound;
	public var inst:FlxSound;

	public var dad:Character = null;
	public var gf:Character = null;
	public var boyfriend:Character = null;
	public var boyfriendd:Character = null;

	public var notes:FlxTypedGroup<Note>;
	public var unspawnNotes:Array<Note> = [];
	public var eventNotes:Array<EventNote> = [];

	public var camFollow:FlxObject;

	private static var prevCamFollow:FlxObject;

	public var comboLayer:ComboGroup;

	public var strumLineNotes:FlxTypedGroup<StrumNote>;
	public var opponentStrums:FlxTypedGroup<StrumNote>;
	public var playerStrums:FlxTypedGroup<StrumNote>;
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;

	public var camZooming:Bool = false;
	public var camZoomingMult:Float = 1;
	public var camZoomingDecay:Float = 1;

	private var curSong:String = "";

	public var formattedSong:String;

	public var gfSpeed:Int = 1;
	public var health:Float = 1;
	public var combo:Int = 0;

	public var healthBar:HealthBar;

	public var songPercent:Float = 0;

	public var ratingsData:Array<Rating> = Rating.loadDefault();
	public var fullComboFunction:Void->Void = null;

	private var generatedMusic:Bool = false;

	public var endingSong:Bool = false;
	public var startingSong:Bool = false;

	private var updateTime:Bool = true;

	public static var changedDifficulty:Bool = false;
	public static var chartingMode:Bool = false;

	// Gameplay settings
	public var healthGain:Float = 1;
	public var healthLoss:Float = 1;
	public var instakillOnMiss:Bool = false;
	public var cpuControlled:Bool = false;
	public var practiceMode:Bool = false;

	public var botplaySine:Float = 0;
	public var botplayTxt:FlxText;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var black:FlxCamera;
	public var camOtheristic:FlxCamera;
	public var camOther:FlxCamera;
	public var camHUDDY:FlxCamera;
	public var cameraSpeed:Float = 1;

	public var songScore:Int = 0;
	public var songHits:Int = 0;
	public var songMisses:Int = 0;
	public var scoreTxt:FlxText;

	var timeTxt:FlxText;
	var scoreTxtTween:FlxTween;

	public static var campaignScore:Int = 0;
	public static var campaignMisses:Int = 0;
	public static var seenCutscene:Bool = false;
	public static var deathCounter:Int = 0;

	public var defaultCamZoom:Float = 1.05;

	private var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	public var inCutscene:Bool = false;
	public var skipCountdown:Bool = false;

	var songLength:Float = 0;

	public var boyfriendCameraOffset:Array<Float> = null;
	public var opponentCameraOffset:Array<Float> = null;
	public var girlfriendCameraOffset:Array<Float> = null;

	#if desktop
	// Discord RPC variables
	var storyDifficultyText:String = "";
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	public static var keysPressed:Array<Int> = [];

	#if ACHIEVEMENTS_ALLOWED
	// Achievement shit
	var boyfriendIdleTime:Float = 0.0;
	var boyfriendIdled:Bool = false;
	#end

	// Lua shit
	public static var instance:PlayState;

	#if LUA_ALLOWED
	public var luaArray:Array<FunkinLua> = [];

	private var luaDebugGroup:FlxTypedGroup<DebugLuaText>;
	#end

	public var introSoundsSuffix:String = '';

	// Less laggy controls
	private var keysArray:Array<String>;

	public var precacheList:Map<String, String> = new Map<String, String>();
	public var songName:String;

	// Callbacks for stages
	public var startCallback:Void->Void = null;
	public var endCallback:Void->Void = null;

	public static var stepCur:Int = 0;
	public static var bfCurAnim:String = 'idle';

	var soulMeter:Soulmeter;
	var timeBarH:Timebar;
	var movecamtopos:Bool = true;
	var lastDamageBeat:Int = -1;

	var hitvfx:FlxSprite;
	var bg2:FlxSprite;
	var bg3:FlxSprite;

	public var blackahhh:FlxSprite;
	public var playerfog:FlxSprite;

	var upperBar:FlxSprite;
	var lowerBar:FlxSprite;
	var uB:Float = 0;
	var lB:Float = 0;
	var audioEffectsInst:AudioEffects;
	var audioEffectsVocals:AudioEffects;
	var loadedSaveFile:Bool = false;

	var noirFilter:NoirFilter;

	override public function create() {
		// trace('Playback Rate: ' + playbackRate);
		Paths.clearStoredMemory();

		startCallback = startCountdown;
		endCallback = endSong;

		// for lua
		instance = this;

		PauseSubState.songName = null; // Reset to default
		playbackRate = ClientPrefs.getGameplaySetting('songspeed');
		fullComboFunction = fullComboUpdate;

		keysArray = ['note_left', 'note_down', 'note_up', 'note_right'];

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		// Gameplay settings
		healthGain = ClientPrefs.getGameplaySetting('healthgain');
		healthLoss = ClientPrefs.getGameplaySetting('healthloss');
		instakillOnMiss = ClientPrefs.getGameplaySetting('instakill');
		practiceMode = ClientPrefs.getGameplaySetting('practice');
		cpuControlled = ClientPrefs.getGameplaySetting('botplay');

		// var gameCam:FlxCamera = FlxG.camera;
		camGame = new FlxCamera();
		camHUDDY = new FlxCamera();
		camHUD = new FlxCamera();
		camOtheristic = new FlxCamera();
		camOther = new FlxCamera();
		camHUDDY.bgColor.alpha = 0;
		camHUD.bgColor.alpha = 0;
		camOtheristic.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUDDY, false);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOtheristic, false);
		FlxG.cameras.add(camOther, false);
		camOther.setSize(1920, 1080);
		camOther.setPosition(-200, -120);
		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();

		FlxG.cameras.setDefaultDrawTarget(camGame, true);
		CustomFadeTransition.nextCamera = camOther;

		persistentUpdate = true;
		persistentDraw = true;

		if (SONG == null)
			SONG = Song.loadFromJson('tutorial', 'tutorial');

		Conductor.mapBPMChanges(SONG);
		Conductor.bpm = SONG.bpm;

		formattedSong = Paths.formatPath(SONG.song);

		#if desktop
		storyDifficultyText = Difficulty.getString();

		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		if (isStoryMode)
			detailsText = "Story Mode";
		else
			detailsText = "Freeplay";

		// String for when the game is paused
		detailsPausedText = "Paused - " + detailsText;
		#end

		GameOverSubstate.resetVariables();
		songName = Paths.formatPath(SONG.song);
		if (SONG.stage == null || SONG.stage.length < 1) {
			SONG.stage = StageData.vanillaSongStage(songName);
		}
		curStage = SONG.stage;

		var stageData:StageFile = StageData.getStageFile(curStage);
		if (stageData == null) { // Stage couldn't be found, create a dummy stage for preventing a crash
			stageData = StageData.dummy();
		}

		defaultCamZoom = stageData.defaultZoom;

		stageUI = "normal";
		if (stageData.stageUI != null && stageData.stageUI.trim().length > 0)
			stageUI = stageData.stageUI;

		BF_X = stageData.boyfriend[0];
		BF_Y = stageData.boyfriend[1];
		GF_X = stageData.girlfriend[0];
		GF_Y = stageData.girlfriend[1];
		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

		if (stageData.camera_speed != null)
			cameraSpeed = stageData.camera_speed;

		boyfriendCameraOffset = stageData.camera_boyfriend;
		if (boyfriendCameraOffset == null)
			boyfriendCameraOffset = [0, 0];

		opponentCameraOffset = stageData.camera_opponent;
		if (opponentCameraOffset == null)
			opponentCameraOffset = [0, 0];

		girlfriendCameraOffset = stageData.camera_girlfriend;
		if (girlfriendCameraOffset == null)
			girlfriendCameraOffset = [0, 0];

		boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		dadGroup = new FlxSpriteGroup(DAD_X, DAD_Y);
		gfGroup = new FlxSpriteGroup(GF_X, GF_Y);

		/*
			var vignette:FlxSprite = new FlxSprite(0, 0).loadGraphic(Paths.image('stage/vignette', 'hymns'));
			vignette.setGraphicSize(1280, 750);
			vignette.updateHitbox();
			vignette.screenCenterXY();
			vignette.antialiasing = ClientPrefs.data.antialiasing;
			vignette.cameras = [camHUD];
			vignette.blend = BlendMode.MULTIPLY;
			vignette.alpha = 0.2;
			add(vignette);
		 */

		bg2 = new FlxSprite(0, 0).loadGraphic(Paths.image("SoulMeter/huh", 'hymns'));
		bg2.antialiasing = ClientPrefs.data.antialiasing;
		bg2.setGraphicSize(1280, 720);
		bg2.updateHitbox();
		bg2.screenCenterXY();
		bg2.alpha = 0;
		bg2.cameras = [camHUD];
		add(bg2);

		bg3 = new FlxSprite(0, 0).loadGraphic(Paths.image("SoulMeter/what", 'hymns'));
		bg3.antialiasing = ClientPrefs.data.antialiasing;
		bg3.setGraphicSize(1280, 720);
		bg3.updateHitbox();
		bg3.screenCenterXY();
		bg3.alpha = 0;
		bg3.cameras = [camHUD];
		add(bg3);

		soulMeter = new Soulmeter(22, 30, 7, camHUD);
		add(soulMeter);
		timeBarH = new Timebar(12, FlxG.height - 160, camHUD);
		add(timeBarH);

		FlxTween.tween(bg2.scale, {x: bg2.scale.x + 0.05, y: bg2.scale.y + 0.05}, 2, {ease: FlxEase.quadInOut, type: PINGPONG});

		switch (curStage) {
			// case 'hallowseve':
			//	new states.stages.HallowsEve();
			//	movecamtopos = false;
			case 'dirtmouth': new states.stages.Dirtmouth();
			case 'lake': new states.stages.Lake();
			case 'shop': new states.stages.Shop();
		}

		blackahhh = new FlxSprite(-FlxG.width * FlxG.camera.zoom,
			-FlxG.height * FlxG.camera.zoom).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
		blackahhh.scrollFactor.set();
		blackahhh.alpha = 0;
		add(blackahhh);

		playerfog = new FlxSprite(0, 0).loadGraphic(Paths.image('Overworld/whiteglow', 'hymns'));
		playerfog.antialiasing = ClientPrefs.data.antialiasing;
		playerfog.blend = ADD;
		playerfog.scale.set(.75, .75);
		playerfog.updateHitbox();
		playerfog.alpha = 0;

		if (formattedSong == "swindler") {
			playerfog.loadGraphic(Paths.image('Overworld/glow', 'hymns'));
			playerfog.scale.set(.75, .75);
			playerfog.updateHitbox();
			playerfog.alpha = 0;
		}

		add(playerfog);

		add(gfGroup);
		add(dadGroup);
		add(boyfriendGroup);

		#if LUA_ALLOWED
		luaDebugGroup = new FlxTypedGroup<DebugLuaText>();
		luaDebugGroup.cameras = [camOther];
		add(luaDebugGroup);
		#end

		// "GLOBAL" SCRIPTS
		#if LUA_ALLOWED
		var foldersToCheck:Array<String> = Mods.directoriesWithFile(Paths.getPreloadPath(), 'scripts/');
		for (folder in foldersToCheck)
			for (file in FileSystem.readDirectory(folder)) {
				if (file.toLowerCase().endsWith('.lua'))
					new FunkinLua(folder + file);
				if (file.toLowerCase().endsWith('.hx'))
					initHScript(folder + file);
			}
		#end

		// STAGE SCRIPTS
		#if LUA_ALLOWED
		startLuasNamed('stages/' + curStage + '.lua');
		#end

		#if HSCRIPT_ALLOWED
		startHScriptsNamed('stages/' + curStage + '.hx');
		#end

		if (!stageData.hide_girlfriend) {
			if (SONG.gfVersion == null || SONG.gfVersion.length < 1)
				SONG.gfVersion = 'gf'; // Fix for the Chart Editor
			gf = new Character(0, 0, SONG.gfVersion);
			startCharacterPos(gf);
			gf.scrollFactor.set(0.95, 0.95);
			gfGroup.add(gf);
			startCharacterScripts(gf.curCharacter);
		}

		dad = new Character(0, 0, SONG.player2);
		startCharacterPos(dad, true);
		dadGroup.add(dad);
		startCharacterScripts(dad.curCharacter);

		boyfriend = new Character(0, 0, SONG.player1, true);
		boyfriend.visible = true;
		startCharacterPos(boyfriend);
		boyfriendGroup.add(boyfriend);
		startCharacterScripts(boyfriend.curCharacter);

		var bfdeadthing:String = "VBF_DIES";
		switch (formattedSong) {
			case "swindler": bfdeadthing = "vbfswindlerdead";
			case "lichen": bfdeadthing = "vbflichendead";
		}
		boyfriendd = new Character(0, 0, bfdeadthing, true);
		startCharacterPos(boyfriendd);
		boyfriendd.y -= 35;
		boyfriendd.visible = false;
		boyfriendGroup.add(boyfriendd);

		playerfog.x = boyfriendd.x - (playerfog.width / 2) + (boyfriendd.width / 1.25);
		playerfog.y = boyfriendd.y - (playerfog.height / 2) + (boyfriendd.height / 4);

		hitvfx = new FlxSprite(boyfriend.x - 450, boyfriend.y - 275);
		hitvfx.frames = Paths.getSparrowAtlas('Menus/hit', 'hymns');
		hitvfx.animation.addByPrefix('boom', 'hit', 15, false);
		hitvfx.visible = false;
		hitvfx.antialiasing = ClientPrefs.data.antialiasing;
		hitvfx.centerOffsets();
		hitvfx.centerOrigin();
		add(hitvfx);
		if (formattedSong == "swindler") {
			hitvfx.x -= 850;
			hitvfx.scale.set(0.8, 0.8);
		}

		getCamOffsets();

		upperBar = new FlxSprite(-110, -350).makeGraphic(1500, 350, FlxColor.BLACK);
		lowerBar = new FlxSprite(-110, 720).makeGraphic(1500, 350, FlxColor.BLACK);
		upperBar.cameras = [camOtheristic];
		lowerBar.cameras = [camOtheristic];

		uB = upperBar.y;
		lB = lowerBar.y;

		add(upperBar);
		add(lowerBar);

		var camPos:FlxPoint = FlxPoint.get(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);
		if (gf != null) {
			camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition[0];
			camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition[1];
		}

		if (dad.curCharacter.startsWith('gf')) {
			dad.setPosition(GF_X, GF_Y);
			if (gf != null)
				gf.visible = false;
		}
		stagesFunc(function(stage:BaseStage) stage.createPost());

		Conductor.songPosition = -5000 / Conductor.songPosition;

		comboLayer = new ComboGroup();
		comboLayer.cameras = [camHUD];
		add(comboLayer);

		strumLineNotes = new FlxTypedGroup<StrumNote>();
		add(strumLineNotes);
		add(grpNoteSplashes);

		var splash:NoteSplash = new NoteSplash(100, 100);
		grpNoteSplashes.add(splash);
		splash.alpha = 0.000001; // cant make it invisible or it won't allow precaching

		opponentStrums = new FlxTypedGroup<StrumNote>();
		playerStrums = new FlxTypedGroup<StrumNote>();

		generateSong(SONG.song);

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollow.setPosition(camPos.x, camPos.y);
		if (curStage == "lake") {
			dadPos[0] -= FlxG.width / 6;
			defaultCamZoom += 0.05;
			camHUD.alpha = 0;
		}
		if (curStage == 'hallowseve') {
			camFollow.x = bfPos[0];
			camFollow.y = bfPos[1] - 600;
		} else {
			camFollow.x = dadPos[0];
			camFollow.y = dadPos[1];
			camMovement = FlxTween.tween(camFollow, {x: dadPos[0], y: dadPos[1]}, 0.001, {ease: FlxEase.quintOut});
		}
		camPos.put();

		if (prevCamFollow != null) {
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}
		add(camFollow);

		FlxG.camera.follow(camFollow, LOCKON, 0);
		if (curStage == 'hallowseve') {
			FlxG.camera.zoom = 1.3;
		} else {
			FlxG.camera.zoom = defaultCamZoom;
		}
		FlxG.camera.snapToTarget();

		if (curStage == 'hallowseve') {
			var blackShit:FlxSprite = new FlxSprite(-FlxG.width * FlxG.camera.zoom,
				-FlxG.height * FlxG.camera.zoom).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
			blackShit.scrollFactor.set();
			add(blackShit);
			FlxTween.tween(blackShit, {alpha: 0}, 4, {ease: FlxEase.quadIn, startDelay: 3});
			new FlxTimer().start(7, function(tmr:FlxTimer) {
				remove(blackShit, true);
				blackShit.destroy();
			});
		}

		if (ClientPrefs.data.shaders) {
			noirFilter = new NoirFilter(0.0);
			add(noirFilter);

			camGame.addShader(noirFilter.shader);
			camHUD.addShader(noirFilter.shader);
		}

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);
		moveCameraSection();

		healthBar = new HealthBar(0, FlxG.height * (!ClientPrefs.data.downScroll ? 0.89 : 0.11), 'healthBar', function() return health, 0, 2);
		healthBar.screenCenterX();
		healthBar.leftToRight = false;
		healthBar.scrollFactor.set();
		healthBar.visible = !ClientPrefs.data.hideHud;
		healthBar.alpha = ClientPrefs.data.healthBarAlpha;
		reloadHealthBarColors();
		// add(healthBar);

		iconP1 = new HealthIcon(boyfriend.healthIcon, true);
		iconP1.y = healthBar.y - 75;
		iconP1.visible = !ClientPrefs.data.hideHud;
		iconP1.alpha = ClientPrefs.data.healthBarAlpha;
		// add(iconP1);

		iconP2 = new HealthIcon(dad.healthIcon, false);
		iconP2.y = FlxG.height - 160 - (iconP2.height / 4);
		iconP2.alpha = 0;
		add(iconP2);

		scoreTxt = new FlxText(50, FlxG.height * 0.95, FlxG.width, "", 20);
		scoreTxt.setFormat(Constants.UI_FONT, 20, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !ClientPrefs.data.hideHud;
		scoreTxt.antialiasing = ClientPrefs.data.antialiasing;
		add(scoreTxt);

		botplayTxt = new FlxText(52, FlxG.height - 160, FlxG.width - 800, "BOTPLAY", 32);
		botplayTxt.setFormat(Constants.UI_FONT, 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = cpuControlled;
		botplayTxt.antialiasing = ClientPrefs.data.antialiasing;
		add(botplayTxt);
		strumLineNotes.cameras = [camHUD];
		grpNoteSplashes.cameras = [camHUD];
		notes.cameras = [camHUD];

		healthBar.cameras = [camHUD];
		iconP1.cameras = [camHUD];
		iconP2.cameras = [camHUD];
		scoreTxt.cameras = [camHUD];

		botplayTxt.cameras = [camHUD];

		startingSong = true;

		#if LUA_ALLOWED
		for (notetype in noteTypes)
			startLuasNamed('custom_notetypes/' + notetype + '.lua');

		for (event in eventsPushed)
			startLuasNamed('custom_events/' + event + '.lua');
		#end

		#if HSCRIPT_ALLOWED
		for (notetype in noteTypes)
			startHScriptsNamed('custom_notetypes/' + notetype + '.hx');

		for (event in eventsPushed)
			startHScriptsNamed('custom_events/' + event + '.hx');
		#end
		noteTypes = null;
		eventsPushed = null;

		if (eventNotes.length > 1) {
			for (event in eventNotes)
				event.strumTime -= eventEarlyTrigger(event);
			eventNotes.sort(sortByTime);
		}

		// SONG SPECIFIC SCRIPTS
		#if LUA_ALLOWED
		var foldersToCheck:Array<String> = Mods.directoriesWithFile(Paths.getPreloadPath(), 'data/' + songName + '/');
		for (folder in foldersToCheck)
			for (file in FileSystem.readDirectory(folder)) {
				if (file.toLowerCase().endsWith('.lua'))
					new FunkinLua(folder + file);
				if (file.toLowerCase().endsWith('.hx'))
					initHScript(folder + file);
			}
		#end

		startCallback();
		RecalculateRating();

		// PRECACHING MISS SOUNDS BECAUSE I THINK THEY CAN LAG PEOPLE AND FUCK THEM UP IDK HOW HAXE WORKS
		if (ClientPrefs.data.hitsoundVolume > 0)
			precacheList.set('hitsound', 'sound');
		// precacheList.set('missnote1', 'sound');
		// precacheList.set('missnote2', 'sound');
		// precacheList.set('missnote3', 'sound');

		if (PauseSubState.songName != null) {
			precacheList.set(PauseSubState.songName, 'music');
		} else if (ClientPrefs.data.pauseMusic != 'None') {
			precacheList.set(Paths.formatPath(ClientPrefs.data.pauseMusic), 'music');
		}

		precacheList.set('alphabet', 'image');
		resetRPC();

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		callOnScripts('onCreatePost');
		#end

		cacheCountdown();

		for (key => type in precacheList) {
			// trace('Key $key is type $type');
			switch (type) {
				case 'image': Paths.image(key);
				case 'sound': Paths.sound(key);
				case 'music': Paths.music(key);
			}
		}

		/*var cache = new ComboSprite();
			cache.loadSprite("sick");
			cache.alpha = 0.000001;
			comboLayer.add(cache);

			new FlxTimer().start(3, (_) -> {
				cache.kill();
		});*/

		super.create();
		Paths.clearUnusedMemory();

		CustomFadeTransition.nextCamera = camOther;
		if (eventNotes.length < 1)
			checkEventNote();
	}

	function set_songSpeed(value:Float):Float {
		if (generatedMusic) {
			var ratio:Float = value / songSpeed; // funny word huh
			if (ratio != 1) {
				for (note in notes.members)
					note.resizeByRatio(ratio);
				for (note in unspawnNotes)
					note.resizeByRatio(ratio);
			}
		}
		songSpeed = value;
		noteKillOffset = Math.max(Conductor.stepCrochet, 350 / songSpeed * playbackRate);
		return value;
	}

	function set_playbackRate(value:Float):Float {
		if (generatedMusic) {
			if (vocals != null)
				vocals.pitch = value;
			FlxG.sound.music.pitch = value;

			var ratio:Float = playbackRate / value; // funny word huh
			if (ratio != 1) {
				for (note in notes.members)
					note.resizeByRatio(ratio);
				for (note in unspawnNotes)
					note.resizeByRatio(ratio);
			}
		}
		playbackRate = value;
		FlxAnimationController.globalSpeed = value;
		Conductor.safeZoneOffset = (ClientPrefs.data.safeFrames / 60) * 1000 * value;
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		setOnScripts('playbackRate', playbackRate);
		#end
		return value;
	}

	public function addTextToDebug(text:String, color:FlxColor) {
		#if LUA_ALLOWED
		var newText:DebugLuaText = luaDebugGroup.recycle(DebugLuaText);
		newText.text = text;
		newText.color = color;
		newText.disableTime = 6;
		newText.alpha = 1;
		newText.setPosition(10, 8 - newText.height);

		luaDebugGroup.forEachAlive(function(spr:DebugLuaText) {
			spr.y += newText.height + 2;
		});
		luaDebugGroup.add(newText);
		#end
	}

	public function reloadHealthBarColors() {
		healthBar.setColors(FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]),
			FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]));
	}

	public function baldursbreak() {
		stagesFunc(function(stage:BaseStage) {
			stage.chromaticAbberation.amt += 0.7;
			FlxTween.tween(stage.chromaticAbberation, {amt: 0.0}, Conductor.crochet / 1000, {ease: FlxEase.sineOut});
		});
	}

	public function addCharacterToList(newCharacter:String, type:Int) {
		switch (type) {
			case 0:
				if (!boyfriendMap.exists(newCharacter)) {
					var newBoyfriend:Character = new Character(0, 0, newCharacter, true);
					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);
					startCharacterPos(newBoyfriend);
					newBoyfriend.alpha = 0.00001;
					startCharacterScripts(newBoyfriend.curCharacter);
				}

			case 1:
				if (!dadMap.exists(newCharacter)) {
					var newDad:Character = new Character(0, 0, newCharacter);
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					startCharacterPos(newDad, true);
					newDad.alpha = 0.00001;
					startCharacterScripts(newDad.curCharacter);
				}

			case 2:
				if (gf != null && !gfMap.exists(newCharacter)) {
					var newGf:Character = new Character(0, 0, newCharacter);
					newGf.scrollFactor.set(0.95, 0.95);
					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					startCharacterPos(newGf);
					newGf.alpha = 0.00001;
					startCharacterScripts(newGf.curCharacter);
				}
		}
	}

	function startCharacterScripts(name:String) {
		// Lua
		#if LUA_ALLOWED
		var doPush:Bool = false;
		var luaFile:String = 'characters/' + name + '.lua';
		#if MODS_ALLOWED
		var replacePath:String = Paths.modFolders(luaFile);
		if (FileSystem.exists(replacePath)) {
			luaFile = replacePath;
			doPush = true;
		} else {
			luaFile = Paths.getPreloadPath(luaFile);
			if (FileSystem.exists(luaFile))
				doPush = true;
		}
		#else
		luaFile = Paths.getPreloadPath(luaFile);
		if (Assets.exists(luaFile))
			doPush = true;
		#end

		if (doPush) {
			for (script in luaArray) {
				if (script.scriptName == luaFile) {
					doPush = false;
					break;
				}
			}
			if (doPush)
				new FunkinLua(luaFile);
		}
		#end

		// HScript
		#if HSCRIPT_ALLOWED
		var doPush:Bool = false;
		var scriptFile:String = 'characters/' + name + '.hx';
		var replacePath:String = Paths.modFolders(scriptFile);
		if (FileSystem.exists(replacePath)) {
			scriptFile = replacePath;
			doPush = true;
		} else {
			scriptFile = Paths.getPreloadPath(scriptFile);
			if (FileSystem.exists(scriptFile))
				doPush = true;
		}

		if (doPush) {
			if (SScript.global.exists(scriptFile))
				doPush = false;

			if (doPush)
				initHScript(scriptFile);
		}
		#end
	}

	public function getLuaObject(tag:String, text:Bool = true):FlxSprite {
		#if LUA_ALLOWED
		if (modchartSprites.exists(tag))
			return modchartSprites.get(tag);
		if (text && modchartTexts.exists(tag))
			return modchartTexts.get(tag);
		if (variables.exists(tag))
			return variables.get(tag);
		#end
		return null;
	}

	function startCharacterPos(char:Character, ?gfCheck:Bool = false) {
		if (gfCheck && char.curCharacter.startsWith('gf')) { // IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	function lowPass(effect:AudioEffects) {
		if (effect == null)
			return;

		effect.lowpassGain = 0.5;
		effect.lowpassGainHF = 0.25;
		effect.tween(1, 1, 0.35, 0.15);
		effect.update(0);
	}

	function lowFilter() {
		// FlxG.sound.music.volume = 0;
		// FlxG.sound.music.fadeIn(Conductor.crochet / 1000 * 4, 0, 1);
		lowPass(audioEffectsInst);
		lowPass(audioEffectsVocals);
		// lowPass(audioEffectsVocalsDAD);
		// FlxG.sound.play(Paths.soundRandom('fail', 1, 3), 1);
	}

	public function startVideo(name:String) {
		#if VIDEOS_ALLOWED
		inCutscene = true;

		var filepath:String = Paths.video(name);
		#if sys
		if (!FileSystem.exists(filepath))
		#else
		if (!OpenFlAssets.exists(filepath))
		#end
		{
			FlxG.log.warn('Couldnt find video file: ' + name);
			startAndEnd();
			return;
		}

		var video:FlxVideoSprite = new FlxVideoSprite();
		if (video.load(filepath)) {
			video.bitmap.onFormatSetup.add(() -> {
				video.setGraphicSize(FlxG.width, FlxG.height);
				video.updateHitbox();
			});
			video.bitmap.onEndReached.add(video.destroy);
			video.bitmap.onEndReached.add(startAndEnd);
			video.antialiasing = ClientPrefs.data.antialiasing;
			video.scrollFactor.set();
			video.cameras = [camHUD];
			video.play();
			add(video);
		} else
			startAndEnd();
		#else
		FlxG.log.warn('Platform not supported!');
		startAndEnd();
		return;
		#end
	}

	function startAndEnd() {
		if (endingSong)
			endSong();
		else
			startCountdown();
	}

	var dialogueCount:Int = 0;

	public var psychDialogue:DialogueBoxPsych;

	// You don't have to add a song, just saying. You can just do "startDialogue(DialogueBoxPsych.parseDialogue(Paths.json(songName + '/dialogue')))" and it should load dialogue.json
	public function startDialogue(dialogueFile:DialogueFile, ?song:String = null):Void {
		// TO DO: Make this more flexible, maybe?
		if (psychDialogue != null)
			return;

		if (dialogueFile.dialogue.length > 0) {
			inCutscene = true;
			precacheList.set('dialogue', 'sound');
			precacheList.set('dialogueClose', 'sound');
			psychDialogue = new DialogueBoxPsych(dialogueFile, song);
			psychDialogue.scrollFactor.set();
			if (endingSong) {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					endSong();
				}
			} else {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					startCountdown();
				}
			}
			psychDialogue.nextDialogueThing = startNextDialogue;
			psychDialogue.skipDialogueThing = skipDialogue;
			psychDialogue.cameras = [camHUD];
			add(psychDialogue);
		} else {
			FlxG.log.warn('Your dialogue file is badly formatted!');
			startAndEnd();
		}
	}

	var startTimer:FlxTimer;
	var finishTimer:FlxTimer = null;

	// For being able to mess with the sprites on Lua
	public var countdownReady:FlxSprite;
	public var countdownSet:FlxSprite;
	public var countdownGo:FlxSprite;

	public static var startOnTime:Float = 0;

	function cacheCountdown() {
		/*var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
			var introImagesArray:Array<String> = switch (stageUI) {
				case "pixel": ['${stageUI}UI/ready-pixel', '${stageUI}UI/set-pixel', '${stageUI}UI/date-pixel'];
				case "normal": ["ready", "set", "go"];
				default: ['${stageUI}UI/ready', '${stageUI}UI/set', '${stageUI}UI/go'];
			}
			introAssets.set(stageUI, introImagesArray);
			var introAlts:Array<String> = introAssets.get(stageUI);
			for (asset in introAlts)
				Paths.image(asset); */

		// Paths.sound('intro3' + introSoundsSuffix);
		// Paths.sound('intro2' + introSoundsSuffix);
		// Paths.sound('intro1' + introSoundsSuffix);
		// Paths.sound('introGo' + introSoundsSuffix);
	}

	public function startCountdown() {
		if (startedCountdown) {
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
			callOnScripts('onStartCountdown');
			#end
			return false;
		}

		seenCutscene = true;
		inCutscene = false;
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED) var ret:Dynamic = callOnScripts('onStartCountdown', null, true);
		if (ret != FunkinLua.Function_Stop) #end {
			if (skipCountdown || startOnTime > 0)
				skipArrowStartTween = true;

			generateStaticArrows(0);
			generateStaticArrows(1);
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
			for (i in 0...playerStrums.length) {
				setOnScripts('defaultPlayerStrumX' + i, playerStrums.members[i].x);
				setOnScripts('defaultPlayerStrumY' + i, playerStrums.members[i].y);
			}
			for (i in 0...opponentStrums.length) {
				setOnScripts('defaultOpponentStrumX' + i, opponentStrums.members[i].x);
				setOnScripts('defaultOpponentStrumY' + i, opponentStrums.members[i].y);
				// if(ClientPrefs.data.middleScroll) opponentStrums.members[i].visible = false;
			}
			#end

			startedCountdown = true;
			Conductor.songPosition = -Conductor.crochet * 5;
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
			setOnScripts('startedCountdown', true);
			callOnScripts('onCountdownStarted', null);
			#end

			var swagCounter:Int = 0;
			if (startOnTime > 0) {
				clearNotesBefore(startOnTime);
				setSongTime(startOnTime - 350);
				return true;
			} else if (skipCountdown) {
				setSongTime(0);
				return true;
			}
			moveCameraSection();

			/*var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
				var introImagesArray:Array<String> = switch (stageUI) {
					case "pixel": ['${stageUI}UI/ready-pixel', '${stageUI}UI/set-pixel', '${stageUI}UI/date-pixel'];
					case "normal": ["ready", "set", "go"];
					default: ['${stageUI}UI/ready', '${stageUI}UI/set', '${stageUI}UI/go'];
				}
				introAssets.set(stageUI, introImagesArray);

				var introAlts:Array<String> = introAssets.get(stageUI);
				var antialias:Bool = (ClientPrefs.data.antialiasing); */

			startTimer = new FlxTimer().start(Conductor.crochet / 1000 / playbackRate, function(tmr:FlxTimer) {
				if (gf != null && tmr.loopsLeft % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0 && gf.animation.curAnim != null && !gf.animation.curAnim.name.startsWith("sing") && !gf.stunned)
					gf.dance();
				if (tmr.loopsLeft % boyfriend.danceEveryNumBeats == 0 && boyfriend.animation.curAnim != null && !boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.stunned)
					boyfriend.dance();
				bfCurAnim = "idle";
				if (tmr.loopsLeft % dad.danceEveryNumBeats == 0 && dad.animation.curAnim != null && !dad.animation.curAnim.name.startsWith('sing') && !dad.stunned)
					dad.dance();

				var tick:Countdown = THREE;
				if (formattedSong != "lichen") {
					tick = START;

					FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, 6, {ease: FlxEase.circOut});
					soulMeter.backBoard.animation.play("appear");
					soulMeter.showMasks();
					timeBarH.initialize();
					FlxTween.tween(iconP2, {alpha: 1}, 3, {ease: FlxEase.circOut, startDelay: 1});

					if (curStage == 'hallowseve') {
						FlxTween.tween(camFollow, {y: bfPos[1]}, 8, {ease: FlxEase.circOut});
						new FlxTimer().start(8, function(tmr:FlxTimer) {
							movecamtopos = true;
						});
					}
				} else {
					tick = START;

					FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, 6, {ease: FlxEase.circOut});
				}
				notes.forEachAlive(function(note:Note) {
					if (ClientPrefs.data.opponentStrums || note.mustPress) {
						note.copyAlpha = false;
						note.alpha = note.multAlpha;
						if (ClientPrefs.data.middleScroll && !note.mustPress)
							note.alpha *= 0.35;
					}
				});

				stagesFunc(function(stage:BaseStage) stage.countdownTick(tick, swagCounter));
				#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
				callOnLuas('onCountdownTick', [swagCounter]);
				callOnHScript('onCountdownTick', [tick, swagCounter]);
				#end

				swagCounter += 1;
			});
		}
		return true;
	}

	inline private function createCountdownSprite(image:String, antialias:Bool):FlxSprite {
		var spr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(image));
		spr.cameras = [camHUD];
		spr.scrollFactor.set();
		spr.updateHitbox();

		spr.screenCenterXY();
		spr.antialiasing = antialias;
		insert(members.indexOf(notes), spr);
		FlxTween.tween(spr, {/*y: spr.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
			ease: FlxEase.cubeInOut,
			onComplete: function(twn:FlxTween) {
				remove(spr);
				spr.destroy();
			}
		});
		return spr;
	}

	public function addBehindGF(obj:FlxBasic) {
		insert(members.indexOf(gfGroup), obj);
	}

	public function addBehindBF(obj:FlxBasic) {
		insert(members.indexOf(boyfriendGroup), obj);
	}

	public function addBehindDad(obj:FlxBasic) {
		insert(members.indexOf(dadGroup), obj);
	}

	public function clearNotesBefore(time:Float) {
		var i:Int = unspawnNotes.length - 1;
		while (i >= 0) {
			var daNote:Note = unspawnNotes[i];
			if (daNote.strumTime - 350 < time) {
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				daNote.kill();
				unspawnNotes.remove(daNote);
				daNote.destroy();
			}
			--i;
		}

		i = notes.length - 1;
		while (i >= 0) {
			var daNote:Note = notes.members[i];
			if (daNote.strumTime - 350 < time) {
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				daNote.kill();
				notes.remove(daNote, true);
				daNote.destroy();
			}
			--i;
		}
	}

	public function updateScore(miss:Bool = false) {
		var str:String = TM.checkTransl(ratingName, Paths.formatPath(ratingName));
		if (totalPlayed != 0) {
			var percent:Float = CoolUtil.floorDecimal(ratingPercent * 100, 2);
			str += ' ($percent%) - $ratingFC';
		} else {
			str = "?";
		}

		var scoree = TM.checkTransl("Score", "score");
		var missess = TM.checkTransl("Misses", "misses");
		var ratingg = TM.checkTransl("Rating", "rating");

		scoreTxt.text = scoree + ': ' + songScore + ' | ' + missess + ': ' + songMisses + ' | ' + ratingg + ': ' + str;

		if (ClientPrefs.data.scoreZoom && !miss && !cpuControlled) {
			if (scoreTxtTween != null) {
				scoreTxtTween.cancel();
			}
			scoreTxt.scale.x = 1.075;
			scoreTxt.scale.y = 1.075;
			scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {
				onComplete: function(twn:FlxTween) {
					scoreTxtTween = null;
				}
			});
		}
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		callOnScripts('onUpdateScore', [miss]);
		#end
	}

	public function setSongTime(time:Float) {
		if (time < 0)
			time = 0;

		FlxG.sound.music.pause();
		vocals.pause();

		FlxG.sound.music.time = time;
		FlxG.sound.music.pitch = playbackRate;
		FlxG.sound.music.play();

		if (Conductor.songPosition <= vocals.length) {
			vocals.time = time;
			vocals.pitch = playbackRate;
		}
		vocals.play();
		Conductor.songPosition = time;
	}

	public function startNextDialogue() {
		dialogueCount++;
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		callOnScripts('onNextDialogue', [dialogueCount]);
		#end
	}

	public function skipDialogue() {
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		callOnScripts('onSkipDialogue', [dialogueCount]);
		#end
	}

	function startSong():Void {
		startingSong = false;

		@:privateAccess
		FlxG.sound.playMusic(inst._sound, 1, false);
		FlxG.sound.music.pitch = playbackRate;
		FlxG.sound.music.onComplete = finishSong.bind();
		add(audioEffectsInst = new AudioEffects(FlxG.sound.music));
		add(audioEffectsVocals = new AudioEffects(vocals));
		vocals.play();

		if (startOnTime > 0)
			setSongTime(startOnTime - 500);
		startOnTime = 0;

		if (paused) {
			// trace('Oopsie doopsie! Paused sound');
			FlxG.sound.music.pause();
			vocals.pause();
		}

		// Song duration in a float, useful for the time left feature
		songLength = FlxG.sound.music.length;
		#if desktop
		// Updating Discord Rich Presence (with Time Left)
		DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength);
		#end
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		setOnScripts('songLength', songLength);
		callOnScripts('onSongStart');
		#end
	}

	var debugNum:Int = 0;
	private var noteTypes:Array<String> = [];
	private var eventsPushed:Array<String> = [];

	private function generateSong(dataPath:String):Void {
		// FlxG.log.add(ChartParser.parse());
		songSpeed = PlayState.SONG.speed;
		songSpeedType = ClientPrefs.getGameplaySetting('scrolltype');
		switch (songSpeedType) {
			case "multiplicative": songSpeed = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed');
			case "constant": songSpeed = ClientPrefs.getGameplaySetting('scrollspeed');
		}

		var songData = SONG;
		Conductor.bpm = songData.bpm;

		curSong = songData.song;

		vocals = new FlxSound();
		if (songData.needsVoices)
			vocals.loadEmbedded(Paths.voices(songData.song));

		vocals.pitch = playbackRate;
		FlxG.sound.list.add(vocals);

		inst = new FlxSound().loadEmbedded(Paths.inst(songData.song));
		FlxG.sound.list.add(inst);

		notes = new FlxTypedGroup<Note>();
		notes.active = false;
		add(notes);

		var noteData:Array<SwagSection> = songData.notes;

		var file:String = Paths.json(songName + '/events');
		#if MODS_ALLOWED
		if (FileSystem.exists(Paths.modsJson(songName + '/events')) || FileSystem.exists(file))
		#else
		if (OpenFlAssets.exists(file))
		#end
		{
			var eventsData:Array<Dynamic> = Song.loadFromJson('events', songName).events;
			for (event in eventsData) // Event Notes
				for (i in 0...event[1].length)
					makeEvent(event, i);
		}

		for (section in noteData) {
			for (songNotes in section.sectionNotes) {
				var daStrumTime:Float = songNotes[0];
				var daNoteData:Int = Std.int(songNotes[1] % 4);
				var gottaHitNote:Bool = section.mustHitSection;

				if (songNotes[1] > 3) {
					gottaHitNote = !section.mustHitSection;
				}
				var oldNote:Note;

				if (unspawnNotes.length > 0)
					oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];
				else
					oldNote = null;
				var swagNote:Note = new Note(daStrumTime, daNoteData, oldNote);

				swagNote.mustPress = gottaHitNote;
				swagNote.sustainLength = songNotes[2];
				swagNote.gfNote = (section.gfSection && (songNotes[1] < 4));
				swagNote.noteType = songNotes[3];
				if (!Std.isOfType(songNotes[3], String))
					swagNote.noteType = ChartingState.noteTypeList[songNotes[3]]; // Backward compatibility + compatibility with Week 7 charts
				swagNote.scrollFactor.set();
				var susLength:Float = swagNote.sustainLength;

				susLength = susLength / Conductor.stepCrochet;
				unspawnNotes.push(swagNote);
				var floorSus:Int = Math.floor(susLength);

				if (floorSus > 0) {
					for (susNote in 0...floorSus + 1) {
						oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];
						var sustainNote:Note = new Note(daStrumTime + (Conductor.stepCrochet * susNote), daNoteData, oldNote, true);
						sustainNote.mustPress = gottaHitNote;
						sustainNote.gfNote = (section.gfSection && (songNotes[1] < 4));
						sustainNote.noteType = swagNote.noteType;
						sustainNote.scrollFactor.set();
						swagNote.tail.push(sustainNote);
						sustainNote.parent = swagNote;
						unspawnNotes.push(sustainNote);
						sustainNote.correctionOffset = swagNote.height / 2;
						if (oldNote.isSustainNote) {
							oldNote.scale.y *= Note.SUSTAIN_SIZE / oldNote.frameHeight;
							oldNote.scale.y /= playbackRate;
							oldNote.updateHitbox();
						}
						if (ClientPrefs.data.downScroll)
							sustainNote.correctionOffset = 0;
						if (sustainNote.mustPress)
							sustainNote.x += FlxG.width / 2; // general offset
						else if (ClientPrefs.data.middleScroll) {
							sustainNote.x += 310;
							if (daNoteData > 1) // Up and Right
							{
								sustainNote.x += FlxG.width / 2 + 25;
							}
						}
					}
				}
				if (swagNote.mustPress) {
					swagNote.x += FlxG.width / 2; // general offset
				} else if (ClientPrefs.data.middleScroll) {
					swagNote.x += 310;
					if (daNoteData > 1) // Up and Right
					{
						swagNote.x += FlxG.width / 2 + 25;
					}
				}
				if (!noteTypes.contains(swagNote.noteType)) {
					noteTypes.push(swagNote.noteType);
				}
			}
		}
		for (event in songData.events) // Event Notes
			for (i in 0...event[1].length)
				makeEvent(event, i);
		unspawnNotes.sort(sortByTime);
		generatedMusic = true;
	}

	// called only once per different event (Used for precaching)
	function eventPushed(event:EventNote) {
		eventPushedUnique(event);
		if (eventsPushed.contains(event.event)) {
			return;
		}

		stagesFunc(function(stage:BaseStage) stage.eventPushed(event));
		eventsPushed.push(event.event);
	}

	// called by every event with the same name
	function eventPushedUnique(event:EventNote) {
		var value1 = event.value1;
		var value2 = event.value2;
		switch (event.event) {
			case "Change Character":
				var charType:Int = 0;
				switch (event.value1.toLowerCase()) {
					case 'gf' | 'girlfriend' | '1':
						charType = 2;
					case 'dad' | 'opponent' | '0':
						charType = 1;
					default:
						var val1:Int = Std.parseInt(event.value1);
						if (Math.isNaN(val1))
							val1 = 0;
						charType = val1;
				}

				var newCharacter:String = event.value2;
				addCharacterToList(newCharacter, charType);

			case 'Play Sound':
				precacheList.set(event.value1, 'sound');
				Paths.sound(event.value1);
		}
		stagesFunc(function(stage:BaseStage) stage.eventPushedUnique(event));
	}

	function eventEarlyTrigger(event:EventNote):Float {
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		var returnedValue:Null<Float> = callOnScripts('eventEarlyTrigger', [event.event, event.value1, event.value2, event.strumTime], true, [], [0]);
		if (returnedValue != null && returnedValue != 0 && returnedValue != FunkinLua.Function_Continue) {
			return returnedValue;
		}
		#end

		// switch (event.event) {
		//	case 'Kill Henchmen': // Better timing so that the kill sound matches the beat intended
		//		return 280; // Plays 280ms before the actual position
		// }
		return 0;
	}

	public static function sortByTime(Obj1:Dynamic, Obj2:Dynamic):Int
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);

	function makeEvent(event:Array<Dynamic>, i:Int) {
		var subEvent:EventNote = {
			strumTime: event[0] + ClientPrefs.data.noteOffset,
			event: event[1][i][0],
			value1: event[1][i][1],
			value2: event[1][i][2]
		};
		eventNotes.push(subEvent);
		eventPushed(subEvent);
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		callOnScripts('onEventPushed', [
			subEvent.event,
			subEvent.value1 != null ? subEvent.value1 : '',
			subEvent.value2 != null ? subEvent.value2 : '',
			subEvent.strumTime]);
		#end
	}

	public var skipArrowStartTween:Bool = false; // for lua

	private function generateStaticArrows(player:Int):Void {
		var strumLineX:Float = ClientPrefs.data.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X;
		var strumLineY:Float = ClientPrefs.data.downScroll ? (FlxG.height - 150) : 50;
		var targetAlpha:Float = 1;
		if (player < 1) {
			if (!ClientPrefs.data.opponentStrums)
				targetAlpha = 0;
			else if (ClientPrefs.data.middleScroll)
				targetAlpha = 0.35;
		}
		for (i in 0...4) {
			var babyArrow:StrumNote = new StrumNote(strumLineX, strumLineY, i, player);
			babyArrow.downScroll = ClientPrefs.data.downScroll;
			babyArrow.alpha = targetAlpha;

			if (player == 1)
				playerStrums.add(babyArrow);
			else {
				if (ClientPrefs.data.middleScroll) {
					babyArrow.x += 310;
					if (i > 1) { // Up and Right
						babyArrow.x += FlxG.width / 2 + 25;
					}
				}
				opponentStrums.add(babyArrow);
				babyArrow.alpha = 0;
			}

			strumLineNotes.add(babyArrow);
			babyArrow.postAddedToGroup();
		}
	}

	override function openSubState(SubState:FlxSubState) {
		stagesFunc(function(stage:BaseStage) stage.openSubState(SubState));
		if (paused) {
			if (FlxG.sound.music != null) {
				FlxG.sound.music.pause();
				vocals.pause();
			}

			if (startTimer != null && !startTimer.finished)
				startTimer.active = false;
			if (finishTimer != null && !finishTimer.finished)
				finishTimer.active = false;
			if (songSpeedTween != null)
				songSpeedTween.active = false;

			var chars:Array<Character> = [boyfriend, gf, dad];
			for (char in chars)
				if (char != null && char.colorTween != null)
					char.colorTween.active = false;

			#if LUA_ALLOWED
			for (tween in modchartTweens)
				tween.active = false;
			for (timer in modchartTimers)
				timer.active = false;
			#end
		}

		super.openSubState(SubState);
	}

	override function closeSubState() {
		stagesFunc(function(stage:BaseStage) stage.closeSubState());
		if (paused) {
			if (FlxG.sound.music != null && !startingSong) {
				resyncVocals();
			}

			if (startTimer != null && !startTimer.finished)
				startTimer.active = true;
			if (finishTimer != null && !finishTimer.finished)
				finishTimer.active = true;
			if (songSpeedTween != null)
				songSpeedTween.active = true;

			var chars:Array<Character> = [boyfriend, gf, dad];
			for (char in chars)
				if (char != null && char.colorTween != null)
					char.colorTween.active = true;

			#if LUA_ALLOWED
			for (tween in modchartTweens)
				tween.active = true;
			for (timer in modchartTimers)
				timer.active = true;
			#end

			paused = false;
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
			callOnScripts('onResume');
			#end
			resetRPC(startTimer != null && startTimer.finished);
		}

		super.closeSubState();
	}

	override public function onFocus():Void {
		if (health > 0 && !paused)
			resetRPC(Conductor.songPosition > 0.0);
		super.onFocus();
	}

	override public function onFocusLost():Void {
		#if desktop
		if (health > 0 && !paused)
			DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end

		super.onFocusLost();
	}

	// Updating Discord Rich Presence.
	function resetRPC(?cond:Bool = false) {
		#if desktop
		if (cond)
			DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength - Conductor.songPosition - ClientPrefs.data.noteOffset);
		else
			DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end
	}

	function resyncVocals():Void {
		if (finishTimer != null)
			return;

		vocals.pause();

		FlxG.sound.music.play();
		FlxG.sound.music.pitch = playbackRate;
		Conductor.songPosition = FlxG.sound.music.time;
		if (Conductor.songPosition <= vocals.length) {
			vocals.time = Conductor.songPosition;
			vocals.pitch = playbackRate;
		}
		vocals.play();
	}

	public var paused:Bool = false;
	public var canReset:Bool = true;

	var startedCountdown:Bool = false;
	var canPause:Bool = true;

	override public function update(elapsed:Float) {
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		callOnScripts('onUpdate', [elapsed]);
		#end

		FlxG.camera.followLerp = 0;
		if (!inCutscene && !paused) {
			FlxG.camera.followLerp = FlxMath.bound(elapsed * 2.4 * cameraSpeed * playbackRate / (FlxG.updateFramerate / 60), 0, 1);
			#if ACHIEVEMENTS_ALLOWED
			if (!startingSong && !endingSong && boyfriend.animation.curAnim != null && boyfriend.animation.curAnim.name.startsWith('idle')) {
				boyfriendIdleTime += elapsed;
				if (boyfriendIdleTime >= 0.15) { // Kind of a mercy thing for making the achievement easier to get as it's apparently frustrating to some playerss
					boyfriendIdled = true;
				}
			} else {
				boyfriendIdleTime = 0;
			}
			#end
		}

		super.update(elapsed);

		if (boyfriend.animation.curAnim != null) {
			if (soulMeter.healing == false && boyfriend.animation.curAnim.name == "focusSTART") {
				boyfriend.playAnim("focusEND", true);
			}

			if (boyfriend.animation.curAnim.finished) {
				switch (boyfriend.animation.curAnim.name) {
					case "focusSTART": boyfriend.playAnim("focusEND", true);
					case "focusIMPACT": boyfriend.playAnim("focusEND", true);
					case "focusEND": boyfriend.playAnim("idle", true);
				}
			}
		}

		if (hitvfx != null) {
			if (hitvfx.animation.curAnim != null) {
				if (hitvfx.animation.curAnim.finished) {
					hitvfx.visible = false;
				}
			}
		}

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		setOnScripts('curDecStep', curDecStep);
		setOnScripts('curDecBeat', curDecBeat);
		#end

		if (botplayTxt != null && botplayTxt.visible) {
			botplaySine += 180 * elapsed;
			botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
		}

		if (curBeat % 1 == 0 && generatedMusic && movecamtopos) {
			checkFocus();
		}

		if (bg2 != null) {
			bg2.screenCenterXY();
		}
		if (bg3 != null) {
			bg3.screenCenterXY();
		}

		if (controls.PAUSE && startedCountdown && canPause) {
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED) var ret:Dynamic = callOnScripts('onPause', null, true);
			if (ret != FunkinLua.Function_Stop) #end {
				openPauseMenu();
			}
		}

		if (controls.justPressed('debug_1') && !endingSong && !inCutscene)
			openChartEditor();

		var mult:Float = FlxMath.lerp(.75, iconP1.scale.x, FlxMath.bound(.75 - (elapsed * 3 * playbackRate), 0, .75));
		iconP1.scale.set(mult, mult);
		iconP1.updateHitbox();

		var mult:Float = FlxMath.lerp(.65, iconP2.scale.x, FlxMath.bound(.75 - (elapsed * playbackRate), .5, .65));
		iconP2.scale.set(mult, mult);
		iconP2.updateHitbox();

		var iconOffset:Int = 26;
		if (health > 2)
			health = 2;
		iconP1.x = healthBar.barCenter + (150 * iconP1.scale.x - 150) / 2 - iconOffset;
		iconP2.x = 12 + (iconP2.width / 8) - (150 * iconP1.scale.x - 150) / 8;
		iconP2.y = FlxG.height - 160 - (iconP2.height / 8) + (150 * iconP1.scale.y - 150) / 8;
		iconP1.animation.curAnim.curFrame = (healthBar.percent < 20) ? 1 : 0;
		iconP2.animation.curAnim.curFrame = (songPercent >= 0.5) ? 1 : 0;

		if (controls.justPressed('debug_2') && !endingSong && !inCutscene)
			openCharacterEditor();

		if (startedCountdown && !paused)
			Conductor.songPosition += elapsed * 1000 * playbackRate;

		if (startingSong) {
			if (startedCountdown && Conductor.songPosition >= 0)
				startSong();
			else if (!startedCountdown)
				Conductor.songPosition = -Conductor.crochet * 5;
		} else if (!paused && updateTime) {
			var curTime:Float = Math.max(0, Conductor.songPosition - ClientPrefs.data.noteOffset);
			songPercent = (curTime / songLength);
			var songCalc:Float = (songLength - curTime);
			var secondsTotal:Int = Math.floor(songCalc / 1000);
			if (secondsTotal < 0)
				secondsTotal = 0;
		}

		if (camZooming) {
			var lerpVal = FlxMath.bound(1 - (elapsed * 3.125 * camZoomingDecay * playbackRate), 0, 1);
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom, FlxG.camera.zoom, lerpVal);
			camHUD.zoom = FlxMath.lerp(1, camHUD.zoom, lerpVal);
		}

		#if RELEASE_DEBUG
		FlxG.watch.addQuick("secShit", curSection);
		FlxG.watch.addQuick("beatShit", curBeat);
		FlxG.watch.addQuick("stepShit", curStep);
		#end

		// RESET = Quick Game Over Screen
		if (!ClientPrefs.data.noReset && controls.RESET && canReset && !inCutscene && startedCountdown && !endingSong) {
			health = 0;
			trace("RESET = True");
		}
		doDeathCheck();

		if (unspawnNotes[0] != null) {
			var time:Float = spawnTime * playbackRate;
			if (songSpeed < 1)
				time /= songSpeed;
			if (unspawnNotes[0].multSpeed < 1)
				time /= unspawnNotes[0].multSpeed;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time) {
				var dunceNote:Note = unspawnNotes.shift();
				notes.insert(0, dunceNote);
				dunceNote.spawned = true;

				#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
				callOnLuas('onSpawnNote', [
					notes.members.indexOf(dunceNote),
					dunceNote.noteData,
					dunceNote.noteType,
					dunceNote.isSustainNote,
					dunceNote.strumTime]);
				callOnHScript('onSpawnNote', [dunceNote]);
				#end
			}
		}

		if (generatedMusic) {
			if (!inCutscene) {
				notes.update(elapsed);
				if (!cpuControlled) {
					keysCheck();
				} else if (boyfriend.animation.curAnim != null && boyfriend.holdTimer > Conductor.stepCrochet * (0.0011 / FlxG.sound.music.pitch) * boyfriend.singDuration && boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.animation.curAnim.name.endsWith('miss')) {
					boyfriend.dance();
					bfCurAnim = "idle";
					// boyfriend.animation.curAnim.finish();
				}

				if (notes.length > 0) {
					if (startedCountdown) {
						var fakeCrochet:Float = (60 / SONG.bpm) * 1000;
						notes.forEachAlive(function(daNote:Note) {
							var strumGroup:FlxTypedGroup<StrumNote> = playerStrums;
							if (!daNote.mustPress)
								strumGroup = opponentStrums;
							daNote.alpha = 0;

							var strum:StrumNote = strumGroup.members[daNote.noteData];
							daNote.followStrumNote(strum, fakeCrochet, songSpeed / playbackRate);

							if (daNote.mustPress) {
								if (cpuControlled && !daNote.blockHit && daNote.canBeHit && (daNote.isSustainNote || daNote.strumTime <= Conductor.songPosition))
									goodNoteHit(daNote);
							} else if (daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote)
								opponentNoteHit(daNote);

							if (daNote.isSustainNote && strum.sustainReduce)
								daNote.clipToStrumNote(strum);

							// Kill extremely late notes and cause misses
							if (Conductor.songPosition - daNote.strumTime > noteKillOffset) {
								if (daNote.mustPress && !cpuControlled && !daNote.ignoreNote && !endingSong && (daNote.tooLate || !daNote.wasGoodHit))
									noteMiss(daNote);

								daNote.active = false;
								daNote.visible = false;

								daNote.kill();
								notes.remove(daNote, true);
								daNote.destroy();
							}
						});
					} else {
						notes.forEachAlive(function(daNote:Note) {
							daNote.canBeHit = false;
							daNote.wasGoodHit = false;
						});
					}
				}
			}
			checkEventNote();
		}

		#if RELEASE_DEBUG
		if (!endingSong && !startingSong) {
			if (FlxG.keys.justPressed.ONE) {
				KillNotes();
				FlxG.sound.music.onComplete();
			}
			if (FlxG.keys.justPressed.TWO) { // Go 10 seconds into the future :O
				setSongTime(Conductor.songPosition + 10000);
				clearNotesBefore(Conductor.songPosition);
			}
		}
		#end

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		setOnScripts('cameraX', camFollow.x);
		setOnScripts('cameraY', camFollow.y);
		setOnScripts('botPlay', cpuControlled);
		callOnScripts('onUpdatePost', [elapsed]);
		#end
	}

	public var debouncey:Bool = true;

	function openPauseMenu() {
		if (isDead == false && debouncey) {
			FlxG.camera.followLerp = 0;
			persistentUpdate = false;
			persistentDraw = true;
			paused = true;

			if (FlxG.sound.music != null) {
				FlxG.sound.music.pause();
				vocals.pause();
			}
			if (!cpuControlled) {
				for (note in playerStrums)
					if (note.animation.curAnim != null && note.animation.curAnim.name != 'static') {
						note.playAnim('static');
						note.resetAnim = 0;
					}
			}
			openSubState(new PauseSubState());
			// debouncey = false;
			// }

			#if desktop
			DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
			#end
		}
	}

	function openChartEditor() {}

	function openCharacterEditor() {}

	public var isDead:Bool = false; // Don't mess with this on Lua!!!

	function doDeathCheck(?skipHealthCheck:Bool = false) {
		var healthy:Bool = (health <= 0);

		if (soulMeter != null) {
			healthy = (soulMeter.masks < 0);
		}

		if (((skipHealthCheck && instakillOnMiss) || healthy) && !practiceMode && !isDead) {
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED) var ret:Dynamic = callOnScripts('onGameOver', null, true);
			if (ret != FunkinLua.Function_Stop) #end {
				boyfriend.stunned = true;
				deathCounter++;

				paused = true;

				vocals.stop();
				FlxG.sound.music.stop();

				boyfriend.visible = false;
				hitvfx.visible = false;
				boyfriendd.visible = true;
				camHUD.visible = false;
				camOtheristic.visible = true;
				bg2.alpha = 0;
				bg2.visible = false;

				bg3.alpha = 0;
				bg3.visible = false;

				persistentUpdate = false;
				persistentDraw = true;

				if (formattedSong != "first-steps") {
					#if LUA_ALLOWED
					for (tween in modchartTweens) {
						tween.active = true;
					}
					for (timer in modchartTimers) {
						timer.active = true;
					}
					#end
					if (dad.curCharacter == "elderbug") {
						dad.playAnim("talkLoop", true);
						dad.specialAnim = true;
					}

					openSubState(new GameOverSubstate(BF_X, BF_Y, bfPos[0], bfPos[1]));
					boyfriend.alpha = 0;

					// MusicBeatState.switchState(new GameOverState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));

					#if desktop
					// Game Over doesn't get his own variable because it's only used here
					DiscordClient.changePresence("Game Over - " + detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
					#end
					isDead = true;

					boyfriend.alpha = 0;
				} else {
					boyfriend.visible = true;
					boyfriendd.visible = false;
					openSubState(new SillySub(BF_X, BF_Y, bfPos[0], bfPos[1]));
					isDead = true;
					persistentUpdate = true;
				}

				if (formattedSong == "first-steps") {
					DataSaver.loadData("first steps activate death flag");
					DataSaver.diedonfirststeps = true;
					DataSaver.saveSettings(DataSaver.saveFile);
				}

				return true;
			}
		}
		return false;
	}

	var overlay:FlxSprite;
	var isoverlay:Bool;

	public function checkEventNote() {
		while (eventNotes.length > 0) {
			var leStrumTime:Float = eventNotes[0].strumTime;
			if (Conductor.songPosition < leStrumTime) {
				return;
			}

			var value1:String = '';
			if (eventNotes[0].value1 != null)
				value1 = eventNotes[0].value1;

			var value2:String = '';
			if (eventNotes[0].value2 != null)
				value2 = eventNotes[0].value2;

			triggerEvent(eventNotes[0].event, value1, value2, leStrumTime);
			eventNotes.shift();
		}
	}

	var BnWtween:FlxTween;
	var blackestShit:FlxSprite;

	public function triggerEvent(eventName:String, value1:String, value2:String, strumTime:Float) {
		var flValue1:Null<Float> = Std.parseFloat(value1);
		var flValue2:Null<Float> = Std.parseFloat(value2);
		if (Math.isNaN(flValue1))
			flValue1 = null;
		if (Math.isNaN(flValue2))
			flValue2 = null;

		switch (eventName) {
			case 'Set GF Speed':
				if (flValue1 == null || flValue1 < 1)
					flValue1 = 1;
				gfSpeed = Math.round(flValue1);

			case 'Add Camera Zoom':
				if (ClientPrefs.data.camZooms && FlxG.camera.zoom < 1.35) {
					if (flValue1 == null)
						flValue1 = 0.015;
					if (flValue2 == null)
						flValue2 = 0.03;

					FlxG.camera.zoom += flValue1;
					camHUD.zoom += flValue2;
				}

			case 'Play Animation':
				// trace('Anim to play: ' + value1);
				var char:Character = dad;
				switch (value2.toLowerCase().trim()) {
					case 'bf' | 'boyfriend':
						char = boyfriend;
					case 'gf' | 'girlfriend':
						char = gf;
					default:
						if (flValue2 == null)
							flValue2 = 0;
						switch (Math.round(flValue2)) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null) {
					char.playAnim(value1, true);
					char.specialAnim = true;
				}

			case 'Camera Follow Pos':
				if (camFollow != null) {
					isCameraOnForcedPos = false;
					if (flValue1 != null || flValue2 != null) {
						isCameraOnForcedPos = true;
						if (flValue1 == null)
							flValue1 = 0;
						if (flValue2 == null)
							flValue2 = 0;
						camFollow.x = flValue1;
						camFollow.y = flValue2;
					}
				}

			case 'Alt Idle Animation':
				var char:Character = dad;
				switch (value1.toLowerCase().trim()) {
					case 'gf' | 'girlfriend':
						char = gf;
					case 'boyfriend' | 'bf':
						char = boyfriend;
					default:
						var val:Int = Std.parseInt(value1);
						if (Math.isNaN(val))
							val = 0;

						switch (val) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null) {
					char.idleSuffix = value2;
					char.recalculateDanceIdle();
				}

			case 'Screen Shake':
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];
				for (i in 0...targetsArray.length) {
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = 0;
					var intensity:Float = 0;
					if (split[0] != null)
						duration = Std.parseFloat(split[0].trim());
					if (split[1] != null)
						intensity = Std.parseFloat(split[1].trim());
					if (Math.isNaN(duration))
						duration = 0;
					if (Math.isNaN(intensity))
						intensity = 0;

					if (duration > 0 && intensity != 0) {
						targetsArray[i].shake(intensity, duration);
					}
				}

			case 'Change Character':
				var charType:Int = 0;
				switch (value1.toLowerCase().trim()) {
					case 'gf' | 'girlfriend':
						charType = 2;
					case 'dad' | 'opponent':
						charType = 1;
					default:
						charType = Std.parseInt(value1);
						if (Math.isNaN(charType)) charType = 0;
				}

				switch (charType) {
					case 0:
						if (boyfriend.curCharacter != value2) {
							if (!boyfriendMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var lastAlpha:Float = boyfriend.alpha;
							boyfriend.alpha = 0.00001;
							boyfriend = boyfriendMap.get(value2);
							boyfriend.alpha = lastAlpha;
							iconP1.changeIcon(boyfriend.healthIcon);
						}
						#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
						setOnScripts('boyfriendName', boyfriend.curCharacter);
						#end

					case 1:
						if (dad.curCharacter != value2) {
							if (!dadMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var wasGf:Bool = dad.curCharacter.startsWith('gf-') || dad.curCharacter == 'gf';
							var lastAlpha:Float = dad.alpha;
							dad.alpha = 0.00001;
							dad = dadMap.get(value2);
							if (!dad.curCharacter.startsWith('gf-') && dad.curCharacter != 'gf') {
								if (wasGf && gf != null) {
									gf.visible = true;
								}
							} else if (gf != null) {
								gf.visible = false;
							}
							dad.alpha = lastAlpha;
							iconP2.changeIcon(dad.healthIcon);
						}
						#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
						setOnScripts('dadName', dad.curCharacter);
						#end

					case 2:
						if (gf != null) {
							if (gf.curCharacter != value2) {
								if (!gfMap.exists(value2)) {
									addCharacterToList(value2, charType);
								}

								var lastAlpha:Float = gf.alpha;
								gf.alpha = 0.00001;
								gf = gfMap.get(value2);
								gf.alpha = lastAlpha;
							}
							#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
							setOnScripts('gfName', gf.curCharacter);
							#end
						}
				}
				reloadHealthBarColors();

			case 'Change Scroll Speed':
				if (songSpeedType != "constant") {
					if (flValue1 == null)
						flValue1 = 1;
					if (flValue2 == null)
						flValue2 = 0;

					var newValue:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed') * flValue1;
					if (flValue2 <= 0)
						songSpeed = newValue;
					else
						songSpeedTween = FlxTween.tween(this, {songSpeed: newValue}, flValue2 / playbackRate, {
							ease: FlxEase.linear,
							onComplete: function(twn:FlxTween) {
								songSpeedTween = null;
							}
						});
				}

			case 'Set Property':
				try {
					var split:Array<String> = value1.split('.');
					if (split.length > 1) {
						LuaUtils.setVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1], value2);
					} else {
						LuaUtils.setVarInArray(this, value1, value2);
					}
				} catch (e:Dynamic) {
					addTextToDebug('ERROR ("Set Property" Event) - ' + e.message.substr(0, e.message.indexOf('\n')), FlxColor.RED);
				}

			case 'Play Sound':
				if (flValue2 == null)
					flValue2 = 1;
				FlxG.sound.play(Paths.sound(value1), flValue2);

			case 'Paper Mario BF Turn':
				if (boyfriend.scale.x == 1) {
					singAnimations = ['singRIGHT', 'singDOWN', 'singUP', 'singLEFT'];
				} else {
					singAnimations = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];
				}
				FlxTween.tween(boyfriend.scale, {x: -boyfriend.scale.x}, 2, {ease: FlxEase.quadInOut});

			case 'Change Camera Offset':
				var char = opponentCameraOffset;
				switch (value2.toLowerCase().trim()) {
					case 'bf' | 'boyfriend':
						char = boyfriendCameraOffset;
					default:
						var val2:Int = Std.parseInt(value2);
						if (Math.isNaN(val2))
							val2 = 0;

						switch (val2) {
							case 1: char = boyfriendCameraOffset;
						}
				}

				if (char != null) {
					char[0] = Std.parseFloat(value1.toLowerCase().split(",")[0].trim());
					char[1] = Std.parseFloat(value1.toLowerCase().split(",")[1].trim());
				}

				if (camFocus == "dad") {
					camFocus = "bf";
				} else {
					camFocus = "dad";
				}
				getCamOffsets();
				checkFocus();

			case 'HUD Transparency': FlxTween.tween(camHUD, {alpha: Std.parseFloat(value1)}, Std.parseFloat(value2), {ease: FlxEase.quadOut});

			case 'Set Saturation':
				if (ClientPrefs.data.shaders) {
					var amount:Float = Std.parseFloat(value1);
					var speed:Float = Std.parseFloat(value2);
					if (Math.isNaN(amount))
						amount = 0;

					if (Math.isNaN(speed))
						speed = 0;

					if (BnWtween != null)
						BnWtween.cancel();

					BnWtween = FlxTween.tween(noirFilter, {amt: amount * -1}, speed, {ease: FlxEase.sineOut});
				}
			case 'Set Camera Zoom':
				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);
				if (Math.isNaN(val1))
					val1 = 1;
				if (Math.isNaN(val2))
					val2 = 1;
				if (value2 == null)
					defaultCamZoom = val1;
				else {
					FlxTween.tween(camGame, {zoom: val1}, val2, {
						ease: FlxEase.sineInOut,
						onComplete: function(twn:FlxTween) {
							defaultCamZoom = camGame.zoom;
						}
					});
				}

			case 'Flash Camera':
				var Color:FlxColor = FlxColor.BLACK;
				switch (value1.split('/')[0]) {
					case 'white':
						Color = FlxColor.WHITE;
					case 'red':
						Color = FlxColor.RED;
				}

				var blackShit:FlxSprite = new FlxSprite(-FlxG.width * FlxG.camera.zoom,
					-FlxG.height * FlxG.camera.zoom).makeGraphic(FlxG.width * 3, FlxG.height * 3, Color);
				blackShit.scrollFactor.set();
				blackShit.cameras = [camOtheristic];

				var alph = Std.parseFloat(value1.split('/')[1]);
				if (Math.isNaN(alph)) {
					alph = 1;
				}

				blackShit.alpha = alph;
				add(blackShit);

				FlxTween.tween(blackShit, {alpha: 0}, Std.parseFloat(value2), {ease: FlxEase.quadOut});
				new FlxTimer().start(Std.parseFloat(value2), function(tmr:FlxTimer) {
					remove(blackShit, true);
					blackShit.destroy();
				});

			case 'Cover Camera':
				var Color:FlxColor = FlxColor.BLACK;
				switch (value1) {
					case 'white':
						Color = FlxColor.WHITE;
					case 'red':
						Color = FlxColor.RED;
				}

				if (blackestShit == null) {
					blackestShit = new FlxSprite(-FlxG.width * FlxG.camera.zoom,
						-FlxG.height * FlxG.camera.zoom).makeGraphic(FlxG.width * 3, FlxG.height * 3, Color);
					blackestShit.scrollFactor.set();
					blackestShit.cameras = [camOtheristic];
					add(blackestShit);

					blackestShit.visible = false;
				}

				blackestShit.visible = !blackestShit.visible;

			case 'RFlash Camera':
				var Color:FlxColor = FlxColor.BLACK;
				switch (value1) {
					case 'white':
						Color = FlxColor.WHITE;
					case 'red':
						Color = FlxColor.RED;
				}

				var blackShit:FlxSprite = new FlxSprite(-FlxG.width * FlxG.camera.zoom,
					-FlxG.height * FlxG.camera.zoom).makeGraphic(FlxG.width * 3, FlxG.height * 3, Color);
				blackShit.scrollFactor.set();
				blackShit.cameras = [camOtheristic];
				blackShit.alpha = 0;
				add(blackShit);

				FlxTween.tween(blackShit, {alpha: 1}, Std.parseFloat(value2), {ease: FlxEase.quadOut});
				new FlxTimer().start(Std.parseFloat(value2), function(tmr:FlxTimer) {
					remove(blackShit, true);
					blackShit.destroy();
				});

			case 'Make Vignette':
				if (overlay == null) {
					overlay = new FlxSprite(0, 0).loadGraphic(Paths.image('shadow', 'hymns'));
					overlay.setGraphicSize(1280, 720);
					overlay.updateHitbox();
					overlay.screenCenterXY();
					overlay.antialiasing = ClientPrefs.data.antialiasing;
					overlay.cameras = [camOtheristic];
					overlay.alpha = 0;
					add(overlay);
				}

				var speed = Std.parseFloat(value1);
				if (Math.isNaN(speed)) {
					speed = 1;
				}

				var splitShit = value2.split('/');

				if (value2 == "" || value2 == null) {
					splitShit = ["" + !isoverlay, "1"];
				}

				var tof:Dynamic = splitShit[0];
				var alpha = Std.parseFloat(splitShit[1]);
				if (Math.isNaN(alpha)) {
					alpha = 1;
				}

				if (tof == "true" || tof == true) {
					FlxTween.tween(overlay, {alpha: alpha}, speed, {ease: FlxEase.quadOut});
					isoverlay = true;
				} else {
					FlxTween.tween(overlay, {alpha: 0}, speed, {ease: FlxEase.quadOut});
					isoverlay = false;
				}

			case 'Cinematic Bars':
				var splitShit = value1.split('/');
				var speed = Std.parseFloat(splitShit[0]);
				var distance = Std.parseFloat(splitShit[1]);

				switch (value2.toLowerCase()) {
					default:
						upperBar.cameras = [camHUDDY];
						lowerBar.cameras = [camHUDDY];
					case 'game' | 'camgame':
						upperBar.cameras = [camGame];
						lowerBar.cameras = [camGame];
					case 'other' | 'camother':
						upperBar.cameras = [camOtheristic];
						lowerBar.cameras = [camOtheristic];
				}

				if (distance > 0) {
					FlxTween.tween(upperBar, {y: uB + distance}, speed, {ease: FlxEase.quadOut});
					FlxTween.tween(lowerBar, {y: lB - distance}, speed, {ease: FlxEase.quadOut});
				} else {
					FlxTween.tween(upperBar, {y: uB}, speed, {ease: FlxEase.quadIn});
					FlxTween.tween(lowerBar, {y: lB}, speed, {ease: FlxEase.quadIn});
				}

			case 'Soulmeter':
				soulMeter.backBoard.animation.play("appear");
				soulMeter.showMasks();
				timeBarH.initialize();
				FlxTween.tween(iconP2, {alpha: 1}, 3, {ease: FlxEase.circOut, startDelay: 1});
		}

		stagesFunc(function(stage:BaseStage) stage.eventCalled(eventName, value1, value2, flValue1, flValue2, strumTime));
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		callOnScripts('onEvent', [eventName, value1, value2, strumTime]);
		#end
	}

	function moveCameraSection(?sec:Null<Int>):Void {
		if (sec == null)
			sec = curSection;
		if (sec < 0)
			sec = 0;

		if (SONG.notes[sec] == null)
			return;

		if (gf != null && SONG.notes[sec].gfSection) {
			// camFollow.setPosition(gf.getMidpoint().x, gf.getMidpoint().y);
			// camFollow.x += gf.cameraPosition[0] + girlfriendCameraOffset[0];
			// camFollow.y += gf.cameraPosition[1] + girlfriendCameraOffset[1];
			// tweenCamIn();
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
			callOnScripts('onMoveCamera', ['gf']);
			#end
			return;
		}

		var isDad:Bool = (SONG.notes[sec].mustHitSection != true);
		// moveCamera(isDad);
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		callOnScripts('onMoveCamera', [isDad ? 'dad' : 'boyfriend']);
		#end
	}

	var cameraTwn:FlxTween;

	public function moveCamera(isDad:Bool) {
		//
	}

	public function tweenCamIn() {
		//
	}

	public function finishSong(?ignoreNoteOffset:Bool = false):Void {
		updateTime = false;
		FlxG.sound.music.volume = 0;
		vocals.volume = 0;
		vocals.pause();
		if (ClientPrefs.data.noteOffset <= 0 || ignoreNoteOffset) {
			endCallback();
		} else {
			finishTimer = new FlxTimer().start(ClientPrefs.data.noteOffset / 1000, function(tmr:FlxTimer) {
				endCallback();
			});
		}
	}

	public var transitioning = false;

	public function endSong() {
		// Should kill you if you tried to cheat
		if (!startingSong) {
			notes.forEach(function(daNote:Note) {
				if (daNote.strumTime < songLength - Conductor.safeZoneOffset) {
					health -= 0.05 * healthLoss;
				}
			});
			for (daNote in unspawnNotes) {
				if (daNote.strumTime < songLength - Conductor.safeZoneOffset) {
					health -= 0.05 * healthLoss;
				}
			}

			if (doDeathCheck()) {
				return false;
			}
		}

		canPause = false;
		endingSong = true;
		camZooming = false;
		inCutscene = false;
		updateTime = false;

		deathCounter = 0;
		seenCutscene = false;

		#if ACHIEVEMENTS_ALLOWED
		if (achievementObj != null)
			return false;
		else {
			var noMissWeek:String = WeekData.getWeekFileName() + '_nomiss';
			var achieve:String = checkForAchievement([noMissWeek, 'ur_bad', 'ur_good', 'hype', 'two_keys', 'toastie', 'debugger']);
			if (achieve != null) {
				startAchievement(achieve);
				return false;
			}
		}
		#end

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		var ret:Dynamic = callOnScripts('onEndSong', null, true);
		if (ret == FunkinLua.Function_Stop)
			return true;
		#end
		if (transitioning)
			return true;

		#if !switch
		var percent:Float = ratingPercent;
		if (Math.isNaN(percent))
			percent = 0;

		Highscore.saveScore(SONG.song, songScore, storyDifficulty, percent);

		var oldScore:Null<Int> = DataSaver.songScores.get(SONG.song);
		var oldRating:Null<Float> = DataSaver.songRating.get(SONG.song);
		if (oldScore == null || oldRating == null || oldScore < songScore) {
			DataSaver.songRating.set(SONG.song, percent);
			DataSaver.songScores.set(SONG.song, songScore);
		}
		#end
		playbackRate = 1;

		if (chartingMode) {
			openChartEditor();
			return false;
		}
		var geoToAdd = Std.int(songLength / 1000 * 1.6);
		DataSaver.loadData('Add ${geoToAdd} geo on win');
		if (Paths.formatPath(DataSaver.doingsong) == "first-steps") {
			geoToAdd = Std.int(Math.max(geoToAdd, 50));
			DataSaver.elderbugstate = 6;
		}
		DataSaver.geo += geoToAdd;
		trace(SONG.song);
		if (formattedSong == "lichen") {
			DataSaver.lichendone = true;
		}
		DataSaver.saveSettings(DataSaver.saveFile);
		ClientPrefs.saveSettings();
		if (isStoryMode) {
			campaignScore += songScore;
			campaignMisses += songMisses;

			trace('WENT BACK TO FREEPLAY??');
			Mods.loadTopMod();
			#if desktop DiscordClient.resetClientID(); #end

			cancelMusicFadeTween();
			if (FlxTransitionableState.skipNextTransIn) {
				CustomFadeTransition.nextCamera = null;
			}
			if (formattedSong == "swindler") {
				OverworldManager.setplayerLocation("Sly");
				OverworldManager.postSongDialogue = "swindler";
			} else {
				OverworldManager.setplayerLocation("Dirtmouth");
				OverworldManager.postSongDialogue = "first-steps";
			}
			MusicBeatState.switchState(new OverworldManager());
			changedDifficulty = false;
		} else {
			trace('WENT BACK TO FREEPLAY??');
			Mods.loadTopMod();
			#if desktop DiscordClient.resetClientID(); #end

			cancelMusicFadeTween();
			if (FlxTransitionableState.skipNextTransIn) {
				CustomFadeTransition.nextCamera = null;
			}
			MusicBeatState.switchState(new FreeplayState());
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			changedDifficulty = false;
		}
		transitioning = true;

		return true;
	}

	#if ACHIEVEMENTS_ALLOWED
	var achievementObj:AchievementPopup = null;

	function startAchievement(achieve:String) {
		achievementObj = new AchievementPopup(achieve, camOther);
		achievementObj.onFinish = achievementEnd;
		add(achievementObj);
		trace('Giving achievement ' + achieve);
	}

	function achievementEnd():Void {
		achievementObj = null;
		if (endingSong && !inCutscene) {
			endSong();
		}
	}
	#end

	public function KillNotes() {
		while (notes.length > 0) {
			var daNote:Note = notes.members[0];
			daNote.active = false;
			daNote.visible = false;

			daNote.kill();
			notes.remove(daNote, true);
			daNote.destroy();
		}
		unspawnNotes = [];
		eventNotes = [];
	}

	public var totalPlayed:Int = 0;
	public var totalNotesHit:Float = 0.0;
	public var showComboNum:Bool = false;
	public var showRating:Bool = false;

	var alphaZero = @:fixed {alpha: 0};

	private function cachePopUpScore() {
		/*var uiPrefix:String = '';
			var uiSuffix:String = '';
			if (stageUI != "normal") {
				uiPrefix = '${stageUI}UI/';
			}

			for (rating in ratingsData)
				Paths.image(uiPrefix + rating.image + uiSuffix);
			for (i in 0...10)
				Paths.image(uiPrefix + 'num' + i + uiSuffix); */
	}

	private function popUpScore(note:Note):Void {
		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.data.ratingOffset);
		var score:Int = 350;

		// tryna do MS based judgment due to popular demand
		var daRating:Rating = Conductor.judgeNote(ratingsData, noteDiff / playbackRate);

		totalNotesHit += daRating.ratingMod;
		note.ratingMod = daRating.ratingMod;
		if (!note.ratingDisabled)
			daRating.hits++;
		note.rating = daRating.name;
		score = daRating.score;

		if (daRating.noteSplash && !note.noteSplashData.disabled)
			spawnNoteSplashOnNote(note);

		if (!practiceMode && !cpuControlled) {
			songScore += score;
			if (!note.ratingDisabled) {
				songHits++;
				totalPlayed++;
				RecalculateRating(false);
			}
		}

		/*if (ClientPrefs.data.hideHud)
				return;

			if (!ClientPrefs.data.comboStacking) {
				comboLayer.forEach((v) -> {
					FlxTween.cancelTweensOf(v); // unsure since resetprops does it
					v.kill();
				});
			}

			var placement:Float = FlxG.width * 0.35;

			var uiPrefix:String = "";
			var uiSuffix:String = '';
			var antialias:Bool = ClientPrefs.data.antialiasing;

			if (stageUI != "normal") {
				uiPrefix = '${stageUI}UI/';
			}

			if (showRating) {
				var rating = comboLayer.recycleLoop(ComboSprite).resetProps();
				rating.loadSprite(uiPrefix + daRating.image + uiSuffix);
				rating.screenCenterY();
				rating.x = placement - 40;
				rating.y -= 60;
				rating.acceleration.y = 550;
				rating.velocity.y -= FlxG.random.int(140, 175);
				rating.velocity.x -= FlxG.random.int(0, 10);
				rating.x += ClientPrefs.data.comboOffset[0];
				rating.y -= ClientPrefs.data.comboOffset[1];

				rating.setGraphicSize(Std.int(rating.width * 0.7));
				rating.antialiasing = ClientPrefs.data.antialiasing;

				rating.updateHitbox();

				FlxTween.tween(rating, alphaZero, 0.2, {
					startDelay: Conductor.crochet * 0.001,
					onComplete: function(tween:FlxTween) {
						rating.kill();
					}
				});

				comboLayer.addEnd(rating);
			}

			if (!showComboNum)
				return;

			var seperatedScore:Array<Int> = [];

			if (combo >= 1000) {
				seperatedScore.push(Math.floor(combo / 1000) % 10);
			}
			seperatedScore.push(Math.floor(combo / 100) % 10);
			seperatedScore.push(Math.floor(combo / 10) % 10);
			seperatedScore.push(combo % 10);

			var daLoop:Int = 0;
			for (i in seperatedScore) {
				var numScore = comboLayer.recycleLoop(ComboSprite).resetProps();
				numScore.loadSprite(uiPrefix + 'num' + Std.string(i) + uiSuffix);
				numScore.screenCenterY();
				numScore.x = placement + (43 * daLoop) - 90;
				numScore.y += 80;

				numScore.x += ClientPrefs.data.comboOffset[2];
				numScore.y -= ClientPrefs.data.comboOffset[3];

				numScore.antialiasing = ClientPrefs.data.antialiasing;
				numScore.setGraphicSize(Std.int(numScore.width * 0.5));
				numScore.updateHitbox();

				numScore.acceleration.y = FlxG.random.int(200, 300);
				numScore.velocity.y -= FlxG.random.int(140, 160);
				numScore.velocity.x = FlxG.random.float(-5, 5);

				comboLayer.addEnd(numScore);

				FlxTween.tween(numScore, alphaZero, 0.2, {
					onComplete: function(tween:FlxTween) {
						numScore.kill();
					},
					startDelay: Conductor.crochet * 0.002
				});

				daLoop++;
		}*/
	}

	public var strumsBlocked:Array<Bool> = [];

	private function onKeyPress(event:KeyboardEvent):Void {
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(keysArray, eventKey);
		if (!controls.controllerMode && FlxG.keys.checkStatus(eventKey, JUST_PRESSED))
			keyPressed(key);
	}

	private function keyPressed(key:Int) {
		if (!cpuControlled && startedCountdown && !paused && key > -1) {
			if (notes.length > 0 && !boyfriend.stunned && generatedMusic && !endingSong) {
				// more accurate hit time for the ratings?
				var lastTime:Float = Conductor.songPosition;
				if (Conductor.songPosition >= 0)
					Conductor.songPosition = FlxG.sound.music.time;

				var canMiss:Bool = !ClientPrefs.data.ghostTapping;

				// heavily based on my own code LOL if it aint broke dont fix it
				var pressNotes:Array<Note> = [];
				var notesStopped:Bool = false;
				var sortedNotesList:Array<Note> = [];
				notes.forEachAlive(function(daNote:Note) {
					if (strumsBlocked[daNote.noteData] != true && daNote.canBeHit && daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit && !daNote.isSustainNote && !daNote.blockHit) {
						if (daNote.noteData == key)
							sortedNotesList.push(daNote);
						canMiss = true;
					}
				});
				sortedNotesList.sort(sortHitNotes);

				if (sortedNotesList.length > 0) {
					for (epicNote in sortedNotesList) {
						for (doubleNote in pressNotes) {
							if (Math.abs(doubleNote.strumTime - epicNote.strumTime) < 1) {
								doubleNote.kill();
								notes.remove(doubleNote, true);
								doubleNote.destroy();
							} else
								notesStopped = true;
						}

						// eee jack detection before was not super good
						if (!notesStopped) {
							goodNoteHit(epicNote);
							pressNotes.push(epicNote);
						}
					}
				} else {
					#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
					callOnScripts('onGhostTap', [key]);
					#end
					if (canMiss && !boyfriend.stunned)
						noteMissPress(key);
				}

				if (!keysPressed.contains(key))
					keysPressed.push(key);

				// more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
				Conductor.songPosition = lastTime;
			}

			var spr:StrumNote = playerStrums.members[key];
			if (strumsBlocked[key] != true && spr != null && spr.animation.curAnim.name != 'confirm') {
				spr.playAnim('pressed');
				spr.resetAnim = 0;
			}
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
			callOnScripts('onKeyPress', [key]);
			#end
		}
	}

	public static function sortHitNotes(a:Note, b:Note):Int {
		if (a.lowPriority && !b.lowPriority)
			return 1;
		else if (!a.lowPriority && b.lowPriority)
			return -1;

		return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
	}

	private function onKeyRelease(event:KeyboardEvent):Void {
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(keysArray, eventKey);
		// trace('Pressed: ' + eventKey);

		if (!controls.controllerMode && key > -1)
			keyReleased(key);
	}

	private function keyReleased(key:Int) {
		if (!cpuControlled && startedCountdown && !paused) {
			var spr:StrumNote = playerStrums.members[key];
			if (spr != null) {
				spr.playAnim('static');
				spr.resetAnim = 0;
			}
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
			callOnScripts('onKeyRelease', [key]);
			#end
		}
	}

	public static function getKeyFromEvent(arr:Array<String>, key:FlxKey):Int {
		if (key != NONE) {
			for (i in 0...arr.length) {
				var note:Array<FlxKey> = Controls.instance.keyboardBinds[arr[i]];
				for (noteKey in note)
					if (key == noteKey)
						return i;
			}
		}
		return -1;
	}

	// Hold notes
	private function keysCheck():Void {
		// HOLDING
		var holdArray:Array<Bool> = [];
		var pressArray:Array<Bool> = [];
		var releaseArray:Array<Bool> = [];
		for (key in keysArray) {
			holdArray.push(controls.pressed(key));
			pressArray.push(controls.justPressed(key));
			releaseArray.push(controls.justReleased(key));
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if (controls.controllerMode && pressArray.contains(true))
			for (i in 0...pressArray.length)
				if (pressArray[i] && strumsBlocked[i] != true)
					keyPressed(i);

		if (startedCountdown && !boyfriend.stunned && generatedMusic) {
			// rewritten inputs???
			if (notes.length > 0) {
				notes.forEachAlive(function(daNote:Note) {
					// hold note functions
					if (strumsBlocked[daNote.noteData] != true && daNote.isSustainNote && holdArray[daNote.noteData] && daNote.canBeHit && daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit && !daNote.blockHit) {
						goodNoteHit(daNote);
					}
				});
			}

			if (holdArray.contains(true) && !endingSong) {
				#if ACHIEVEMENTS_ALLOWED
				var achieve:String = checkForAchievement(['oversinging']);
				if (achieve != null) {
					startAchievement(achieve);
				}
				#end
			} else if (boyfriend.animation.curAnim != null && boyfriend.holdTimer > Conductor.stepCrochet * (0.0011 / FlxG.sound.music.pitch) * boyfriend.singDuration && boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.animation.curAnim.name.endsWith('miss')) {
				boyfriend.dance();
				bfCurAnim = "idle";
				// boyfriend.animation.curAnim.finish();
			}
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if ((controls.controllerMode || strumsBlocked.contains(true)) && releaseArray.contains(true))
			for (i in 0...releaseArray.length)
				if (releaseArray[i] || strumsBlocked[i] == true)
					keyReleased(i);
	}

	function noteMiss(daNote:Note):Void { // You didn't hit the key and let it go offscreen, also used by Hurt Notes
		// Dupe note remove
		notes.forEachAlive(function(note:Note) {
			if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 1) {
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		});
		// lowFilter();

		noteMissCommon(daNote.noteData, daNote);
		// var result:Dynamic = callOnLuas('noteMiss', [notes.members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote]);
		// if (result != FunkinLua.Function_Stop && result != FunkinLua.Function_StopHScript && result != FunkinLua.Function_StopAll)
		//	callOnHScript('noteMiss', [daNote]);
	}

	function noteMissPress(direction:Int = 1):Void // You pressed a key when there was no notes to press for this key
	{
		if (ClientPrefs.data.ghostTapping)
			return; // fuck it
		// lowFilter();

		bfCurAnim = "move";
		noteMissCommon(direction);
		// FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		callOnScripts('noteMissPress', [direction]);
		#end
	}

	var bg2tween:FlxTween;
	var bg3tween:FlxTween;

	function noteMissCommon(direction:Int, note:Note = null) {
		// score and data
		var subtract:Float = 0.05;
		if (note != null)
			subtract = note.missHealth;
		health -= subtract * healthLoss;
		if (soulMeter != null && !note.isSustainNote && curBeat > lastDamageBeat + 0) { // +1 for two beats
			lastDamageBeat = curBeat;
			if (DataSaver.isOvercharmed) {
				soulMeter.changeMasks(-2);
			} else {
				soulMeter.changeMasks(-1);
			}
			hitvfx.visible = true;
			hitvfx.animation.play('boom', true);
			lowFilter();

			boyfriend.color = 0xFF000000;
			FlxTween.color(boyfriend, .35, FlxColor.BLACK, FlxColor.WHITE, {ease: FlxEase.quadInOut});

			if (bg2tween != null) {
				bg2tween.cancel();
			}
			if (bg3tween != null) {
				bg3tween.cancel();
			}
			function tweenOut2(flxT:FlxTween) {
				bg2tween = FlxTween.tween(bg2, {alpha: 0}, 4, {ease: FlxEase.quintOut, startDelay: 4});
			}
			function tweenOut3(flxT:FlxTween) {
				bg3tween = FlxTween.tween(bg3, {alpha: 0}, .35, {ease: FlxEase.quintOut});
			}

			if (soulMeter.masks < 1) {
				bg2tween = FlxTween.tween(bg2, {alpha: 0.4}, 0.35, {ease: FlxEase.quintOut, onComplete: tweenOut2});
			} else {
				bg3tween = FlxTween.tween(bg3, {alpha: 0.6}, 0.35, {ease: FlxEase.quintOut, onComplete: tweenOut3});
			}

			if (!loadedSaveFile) {
				DataSaver.loadData("loaded save file on miss");
				loadedSaveFile = true;
			}
		}

		if (instakillOnMiss) {
			vocals.volume = 0;
			doDeathCheck(true);
		}
		combo = 0;

		if (!practiceMode)
			songScore -= 10;
		if (!endingSong)
			songMisses++;
		totalPlayed++;
		RecalculateRating(true);

		// play character anims
		var char:Character = boyfriend;
		bfCurAnim = "move";
		if ((note != null && note.gfNote) || (SONG.notes[curSection] != null && SONG.notes[curSection].gfSection))
			char = gf;

		if (char != null && char.hasMissAnimations) {
			var suffix:String = '';
			if (note != null)
				suffix = note.animSuffix;

			var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length - 1, direction)))] + 'miss' + suffix;
			char.playAnim(animToPlay, true);

			if (camFocus == 'bf') {
				triggerCamMovement(Math.abs(note.noteData % 4));
			}

			if (char != gf && combo > 5 && gf != null && gf.animOffsets.exists('sad')) {
				gf.playAnim('sad');
				gf.specialAnim = true;
			}
		}
		vocals.volume = 0;
	}

	function opponentNoteHit(note:Note):Void {
		if (formattedSong != 'tutorial')
			camZooming = false;

		if (note.noteType == 'Hey!' && dad.animOffsets.exists('hey')) {
			dad.playAnim('hey', true);
			dad.specialAnim = true;
			dad.heyTimer = 0.6;
		} else if (!note.noAnimation) {
			var altAnim:String = note.animSuffix;

			if (SONG.notes[curSection] != null) {
				if (SONG.notes[curSection].altAnim && !SONG.notes[curSection].gfSection) {
					altAnim = '-alt';
				}
			}

			if (camFocus == 'dad') {
				triggerCamMovement(Math.abs(note.noteData % 4));
			}

			var char:Character = dad;
			var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length - 1, note.noteData)))] + altAnim;
			if (note.gfNote) {
				char = gf;
			}

			if (char != null) {
				char.playAnim(animToPlay, true);
				char.holdTimer = 0;
			}
		}

		if (SONG.needsVoices)
			vocals.volume = 1;

		strumPlayAnim(true, Std.int(Math.abs(note.noteData)), Conductor.stepCrochet * 1.25 / 1000 / playbackRate);
		note.hitByOpponent = true;

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		var result:Dynamic = callOnLuas('opponentNoteHit', [
			notes.members.indexOf(note),
			Math.abs(note.noteData),
			note.noteType,
			note.isSustainNote]);
		if (result != FunkinLua.Function_Stop && result != FunkinLua.Function_StopHScript && result != FunkinLua.Function_StopAll)
			callOnHScript('opponentNoteHit', [note]);
		#end

		if (!note.isSustainNote) {
			note.kill();
			notes.remove(note, true);
			note.destroy();
		}
	}

	function goodNoteHit(note:Note):Void {
		if (!note.wasGoodHit) {
			if (cpuControlled && (note.ignoreNote || note.hitCausesMiss))
				return;

			note.wasGoodHit = true;
			if (ClientPrefs.data.hitsoundVolume > 0 && !note.hitsoundDisabled)
				FlxG.sound.play(Paths.sound(note.hitsound), ClientPrefs.data.hitsoundVolume);

			if (note.hitCausesMiss) {
				noteMiss(note);
				if (!note.noteSplashData.disabled && !note.isSustainNote)
					spawnNoteSplashOnNote(note);

				if (!note.noMissAnimation) {
					switch (note.noteType) {
						case 'Hurt Note': // Hurt note
							if (boyfriend.animation.getByName('hurt') != null) {
								boyfriend.playAnim('hurt', true);
								boyfriend.specialAnim = true;
							}
					}
				}

				if (!note.isSustainNote) {
					note.kill();
					notes.remove(note, true);
					note.destroy();
				}
				return;
			}

			if (!note.isSustainNote) {
				combo++;
				if (combo > 9999)
					combo = 9999;
				popUpScore(note);
			}
			health += note.hitHealth * healthGain;
			bfCurAnim = "move";
			if (soulMeter != null) {
				if (!loadedSaveFile) {
					DataSaver.loadData("soul meter health gain mask stuff");
					loadedSaveFile = true;
				}
				var rawData:Bool = DataSaver.charms.get(CriticalFocus);

				if (rawData) {
					soulMeter.soul += Math.round(1.25 * healthGain);
					if (soulMeter.masks <= soulMeter.maxMasks / 2) {
						soulMeter.soul += Math.round((1.25 * healthGain) / 2);
					}
				} else {
					soulMeter.soul += Math.round(1.25 * healthGain);
				}
				if (soulMeter.soul >= 99) {
					soulMeter.soul = 99;
				}
			}

			if (!note.noAnimation) {
				var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length - 1, note.noteData)))];

				var char:Character = boyfriend;
				var animCheck:String = 'hey';
				if (note.gfNote) {
					char = gf;
					animCheck = 'cheer';
				}

				if (char != null) {
					char.playAnim(animToPlay + note.animSuffix, true);
					char.holdTimer = 0;

					if (camFocus == 'bf') {
						triggerCamMovement(note.noteData % 4);
					}

					if (note.noteType == 'Hey!') {
						if (char.animOffsets.exists(animCheck)) {
							char.playAnim(animCheck, true);
							char.specialAnim = true;
							char.heyTimer = 0.6;
						}
					}
				}
			}

			if (!cpuControlled) {
				var spr = playerStrums.members[note.noteData];
				if (spr != null)
					spr.playAnim('confirm', true);
			} else
				strumPlayAnim(false, Std.int(Math.abs(note.noteData)), Conductor.stepCrochet * 1.25 / 1000 / playbackRate);
			vocals.volume = 1;

			#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
			var isSus:Bool = note.isSustainNote; // GET OUT OF MY HEAD, GET OUT OF MY HEAD, GET OUT OF MY HEAD
			var leData:Int = Math.round(Math.abs(note.noteData));
			var leType:String = note.noteType;

			var result:Dynamic = callOnLuas('goodNoteHit', [notes.members.indexOf(note), leData, leType, isSus]);
			if (result != FunkinLua.Function_Stop && result != FunkinLua.Function_StopHScript && result != FunkinLua.Function_StopAll)
				callOnHScript('goodNoteHit', [note]);
			#end

			if (!note.isSustainNote) {
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		}
	}

	public function spawnNoteSplashOnNote(note:Note) {
		if (note != null) {
			var strum:StrumNote = playerStrums.members[note.noteData];
			if (strum != null)
				spawnNoteSplash(strum.x, strum.y, note.noteData, note);
		}
	}

	public function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note = null) {
		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.setupNoteSplash(x, y, data, note);
		grpNoteSplashes.add(splash);
	}

	override function destroy() {
		#if LUA_ALLOWED
		for (i in 0...luaArray.length) {
			var lua:FunkinLua = luaArray[0];
			lua.call('onDestroy', []);
			lua.stop();
		}
		luaArray = [];
		FunkinLua.customFunctions.clear();
		#end

		#if HSCRIPT_ALLOWED
		for (script in hscriptArray)
			if (script != null) {
				script.call('onDestroy');
				script.destroy();
			}

		while (hscriptArray.length > 0)
			hscriptArray.pop();
		#end

		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		FlxAnimationController.globalSpeed = 1;
		FlxG.sound.music.pitch = 1;
		backend.NoteTypesConfig.clearNoteTypesData();
		instance = null;
		super.destroy();
	}

	public static function cancelMusicFadeTween() {
		if (FlxG.sound.music.fadeTween != null) {
			FlxG.sound.music.fadeTween.cancel();
		}
		FlxG.sound.music.fadeTween = null;
	}

	var lastStepHit:Int = -1;

	override function stepHit() {
		if (FlxG.sound.music.time >= -ClientPrefs.data.noteOffset) {
			if (Math.abs(FlxG.sound.music.time - (Conductor.songPosition - Conductor.offset)) > (20 * playbackRate) || (SONG.needsVoices && Math.abs(vocals.time - (Conductor.songPosition - Conductor.offset)) > (20 * playbackRate))) {
				resyncVocals();
			}
		}

		super.stepHit();

		if (curStep == lastStepHit) {
			return;
		}

		lastStepHit = curStep;
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		setOnScripts('curStep', curStep);
		callOnScripts('onStepHit');
		#end
	}

	var lastBeatHit:Int = -1;

	override function beatHit() {
		if (lastBeatHit >= curBeat) {
			// trace('BEAT HIT: ' + curBeat + ', LAST HIT: ' + lastBeatHit);
			return;
		}

		if (generatedMusic)
			notes.sort(FlxSort.byY, ClientPrefs.data.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);

		iconP1.scale.set(1.2, 1.2);
		iconP2.scale.set(1.2, 1.2);

		iconP1.updateHitbox();
		iconP2.updateHitbox();

		if (gf != null && curBeat % (gfSpeed * gf.danceEveryNumBeats) == 0 && gf.animation.curAnim != null && !gf.animation.curAnim.name.startsWith("sing") && !gf.stunned)
			gf.dance();
		if (curBeat % boyfriend.danceEveryNumBeats == 0 && boyfriend.animation.curAnim != null && !boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.stunned)
			boyfriend.dance();
		bfCurAnim = "idle";
		if (curBeat % dad.danceEveryNumBeats == 0 && dad.animation.curAnim != null && !dad.animation.curAnim.name.startsWith('sing') && !dad.stunned)
			dad.dance();

		super.beatHit();
		lastBeatHit = curBeat;

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		setOnScripts('curBeat', curBeat);
		callOnScripts('onBeatHit');
		#end
	}

	override function sectionHit() {
		if (SONG.notes[curSection] != null) {
			if (generatedMusic && !endingSong && !isCameraOnForcedPos)
				moveCameraSection();

			if (camZooming && FlxG.camera.zoom < 1.35 && ClientPrefs.data.camZooms) {
				FlxG.camera.zoom += 0.015 * camZoomingMult;
				camHUD.zoom += 0.03 * camZoomingMult;
			}

			if (SONG.notes[curSection].changeBPM) {
				Conductor.bpm = SONG.notes[curSection].bpm;
				#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
				setOnScripts('curBpm', Conductor.bpm);
				setOnScripts('crochet', Conductor.crochet);
				setOnScripts('stepCrochet', Conductor.stepCrochet);
				#end
			}
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
			setOnScripts('mustHitSection', SONG.notes[curSection].mustHitSection);
			setOnScripts('altAnim', SONG.notes[curSection].altAnim);
			setOnScripts('gfSection', SONG.notes[curSection].gfSection);
			#end
		}
		super.sectionHit();

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		setOnScripts('curSection', curSection);
		callOnScripts('onSectionHit');
		#end
	}

	#if LUA_ALLOWED
	public function startLuasNamed(luaFile:String) {
		#if MODS_ALLOWED
		var luaToLoad:String = Paths.modFolders(luaFile);
		if (!FileSystem.exists(luaToLoad))
			luaToLoad = Paths.getPreloadPath(luaFile);

		if (FileSystem.exists(luaToLoad))
		#elseif sys
		var luaToLoad:String = Paths.getPreloadPath(luaFile);
		if (OpenFlAssets.exists(luaToLoad))
		#end
		{
			for (script in luaArray)
				if (script.scriptName == luaToLoad)
					return false;

			new FunkinLua(luaToLoad);
			return true;
		}
		return false;
	}
	#end

	#if HSCRIPT_ALLOWED
	public function startHScriptsNamed(scriptFile:String) {
		var scriptToLoad:String = Paths.modFolders(scriptFile);
		if (!FileSystem.exists(scriptToLoad))
			scriptToLoad = Paths.getPreloadPath(scriptFile);

		if (FileSystem.exists(scriptToLoad)) {
			if (SScript.global.exists(scriptToLoad))
				return false;

			initHScript(scriptToLoad);
			return true;
		}
		return false;
	}

	public function initHScript(file:String) {
		try {
			var newScript:HScript = new HScript(null, file);
			@:privateAccess
			if (newScript.parsingExceptions != null && newScript.parsingExceptions.length > 0) {
				@:privateAccess
				for (e in newScript.parsingExceptions)
					if (e != null)
						addTextToDebug('ERROR ON LOADING ($file): ${e.message.substr(0, e.message.indexOf('\n'))}', FlxColor.RED);
				newScript.destroy();
				return;
			}

			hscriptArray.push(newScript);
			if (newScript.exists('onCreate')) {
				var callValue = newScript.call('onCreate');
				if (!callValue.succeeded) {
					for (e in callValue.exceptions)
						if (e != null)
							addTextToDebug('ERROR ($file: onCreate) - ${e.message.substr(0, e.message.indexOf('\n'))}', FlxColor.RED);

					newScript.destroy();
					hscriptArray.remove(newScript);
					trace('failed to initialize sscript interp!!! ($file)');
				} else
					trace('initialized sscript interp successfully: $file');
			}
		} catch (e) {
			addTextToDebug('ERROR ($file) - ' + e.message.substr(0, e.message.indexOf('\n')), FlxColor.RED);
			var newScript:HScript = cast(SScript.global.get(file), HScript);
			if (newScript != null) {
				newScript.destroy();
				hscriptArray.remove(newScript);
			}
		}
	}
	#end

	#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
	public function callOnScripts(funcToCall:String, args:Array<Dynamic> = null, ignoreStops = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal:Dynamic = psychlua.FunkinLua.Function_Continue;
		if (args == null)
			args = [];
		if (exclusions == null)
			exclusions = [];
		if (excludeValues == null)
			excludeValues = [psychlua.FunkinLua.Function_Continue];

		var result:Dynamic = callOnLuas(funcToCall, args, ignoreStops, exclusions, excludeValues);
		if (result == null || excludeValues.contains(result))
			result = callOnHScript(funcToCall, args, ignoreStops, exclusions, excludeValues);
		return result;
	}

	public function callOnLuas(funcToCall:String, args:Array<Dynamic> = null, ignoreStops = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal:Dynamic = FunkinLua.Function_Continue;
		#if LUA_ALLOWED
		if (args == null)
			args = [];
		if (exclusions == null)
			exclusions = [];
		if (excludeValues == null)
			excludeValues = [FunkinLua.Function_Continue];

		var len:Int = luaArray.length;
		var i:Int = 0;
		while (i < len) {
			var script:FunkinLua = luaArray[i];
			if (exclusions.contains(script.scriptName)) {
				i++;
				continue;
			}

			var myValue:Dynamic = script.call(funcToCall, args);
			if ((myValue == FunkinLua.Function_StopLua || myValue == FunkinLua.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops) {
				returnVal = myValue;
				break;
			}

			if (myValue != null && !excludeValues.contains(myValue))
				returnVal = myValue;

			if (!script.closed)
				i++;
			else
				len--;
		}
		#end
		return returnVal;
	}

	public function callOnHScript(funcToCall:String, args:Array<Dynamic> = null, ?ignoreStops:Bool = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal:Dynamic = psychlua.FunkinLua.Function_Continue;

		#if HSCRIPT_ALLOWED
		if (exclusions == null)
			exclusions = new Array();
		if (excludeValues == null)
			excludeValues = new Array();
		excludeValues.push(psychlua.FunkinLua.Function_Continue);

		var len:Int = hscriptArray.length;
		if (len < 1)
			return returnVal;
		for (i in 0...len) {
			var script:HScript = hscriptArray[i];
			if (script == null || !script.exists(funcToCall) || exclusions.contains(script.origin))
				continue;

			var myValue:Dynamic = null;
			try {
				var callValue = script.call(funcToCall, args);
				if (!callValue.succeeded) {
					var e = callValue.exceptions[0];
					if (e != null)
						FunkinLua.luaTrace('ERROR (${script.origin}: ${callValue.calledFunction}) - ' + e.message.substr(0, e.message.indexOf('\n')), true, false, FlxColor.RED);
				} else {
					myValue = callValue.returnValue;
					if ((myValue == FunkinLua.Function_StopHScript || myValue == FunkinLua.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops) {
						returnVal = myValue;
						break;
					}

					if (myValue != null && !excludeValues.contains(myValue))
						returnVal = myValue;
				}
			}
		}
		#end

		return returnVal;
	}

	public function setOnScripts(variable:String, arg:Dynamic, exclusions:Array<String> = null) {
		if (exclusions == null)
			exclusions = [];
		setOnLuas(variable, arg, exclusions);
		setOnHScript(variable, arg, exclusions);
	}

	public function setOnLuas(variable:String, arg:Dynamic, exclusions:Array<String> = null) {
		#if LUA_ALLOWED
		if (exclusions == null)
			exclusions = [];
		for (script in luaArray) {
			if (exclusions.contains(script.scriptName))
				continue;

			script.set(variable, arg);
		}
		#end
	}

	public function setOnHScript(variable:String, arg:Dynamic, exclusions:Array<String> = null) {
		#if HSCRIPT_ALLOWED
		if (exclusions == null)
			exclusions = [];
		for (script in hscriptArray) {
			if (exclusions.contains(script.origin))
				continue;

			script.set(variable, arg);
		}
		#end
	}
	#end

	function strumPlayAnim(isDad:Bool, id:Int, time:Float) {
		var spr:StrumNote = null;
		if (isDad) {
			spr = opponentStrums.members[id];
		} else {
			spr = playerStrums.members[id];
		}

		if (spr != null) {
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}

	public var ratingName:String = '?';
	public var ratingPercent:Float;
	public var ratingFC:String;

	public function RecalculateRating(badHit:Bool = false) {
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		setOnScripts('score', songScore);
		setOnScripts('misses', songMisses);
		setOnScripts('hits', songHits);
		setOnScripts('combo', combo);
		#end

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED) var ret:Dynamic = callOnScripts('onRecalculateRating', null, true);
		if (ret != FunkinLua.Function_Stop) #end {
			ratingName = '?';
			if (totalPlayed != 0) // Prevent divide by 0
			{
				// Rating Percent
				ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));
				// trace((totalNotesHit / totalPlayed) + ', Total: ' + totalPlayed + ', notes hit: ' + totalNotesHit);

				// Rating Name
				ratingName = ratingStuff[ratingStuff.length - 1][0]; // Uses last string
				if (ratingPercent < 1)
					for (i in 0...ratingStuff.length - 1)
						if (ratingPercent < ratingStuff[i][1]) {
							ratingName = ratingStuff[i][0];
							break;
						}
			}
			fullComboFunction();
		}
		updateScore(badHit); // score will only update after rating is calculated, if it's a badHit, it shouldn't bounce -Ghost
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		setOnScripts('rating', ratingPercent);
		setOnScripts('ratingName', ratingName);
		setOnScripts('ratingFC', ratingFC);
		#end
	}

	function fullComboUpdate() {
		var sicks:Int = ratingsData[0].hits;
		var goods:Int = ratingsData[1].hits;
		var bads:Int = ratingsData[2].hits;
		var shits:Int = ratingsData[3].hits;

		ratingFC = 'Clear';
		if (songMisses < 1) {
			if (bads > 0 || shits > 0)
				ratingFC = 'FC';
			else if (goods > 0)
				ratingFC = 'GFC';
			else if (sicks > 0)
				ratingFC = 'SFC';
		} else if (songMisses < 10)
			ratingFC = 'SDCB';
	}

	#if ACHIEVEMENTS_ALLOWED
	private function checkForAchievement(achievesToCheck:Array<String> = null):String {
		if (chartingMode)
			return null;

		var usedPractice:Bool = (ClientPrefs.getGameplaySetting('practice') || ClientPrefs.getGameplaySetting('botplay'));
		for (i in 0...achievesToCheck.length) {
			var achievementName:String = achievesToCheck[i];
			if (!Achievements.isAchievementUnlocked(achievementName) && !cpuControlled && Achievements.getAchievementIndex(achievementName) > -1) {
				var unlock:Bool = false;
				if (achievementName == WeekData.getWeekFileName() + '_nomiss') // any FC achievements, name should be "weekFileName_nomiss", e.g: "week3_nomiss";
				{
					if (isStoryMode && campaignMisses + songMisses < 1 && Difficulty.getString()
						.toUpperCase() == 'HARD' && storyPlaylist.length <= 1 && !changedDifficulty && !usedPractice)
						unlock = true;
				} else {
					switch (achievementName) {
						case 'ur_bad': unlock = (ratingPercent < 0.2 && !practiceMode);

						case 'ur_good': unlock = (ratingPercent >= 1 && !usedPractice);

						case 'roadkill_enthusiast': unlock = (Achievements.henchmenDeath >= 50);

						case 'oversinging': unlock = (boyfriend.holdTimer >= 10 && !usedPractice);

						case 'hype': unlock = (!boyfriendIdled && !usedPractice);

						case 'two_keys': unlock = (!usedPractice && keysPressed.length <= 2);

						case 'toastie': unlock = (/*ClientPrefs.data.framerate <= 60 &&*/ !ClientPrefs.data.shaders && ClientPrefs.data.lowQuality && !ClientPrefs.data.antialiasing);

						case 'debugger': unlock = (formattedSong == 'test' && !usedPractice);
					}
				}

				if (unlock) {
					Achievements.unlockAchievement(achievementName);
					return achievementName;
				}
			}
		}
		return null;
	}
	#end

	#if (!flash && sys)
	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();

	public function createRuntimeShader(name:String):FlxRuntimeShader {
		if (!ClientPrefs.data.shaders)
			return new FlxRuntimeShader();

		#if (!flash && MODS_ALLOWED && sys)
		if (!runtimeShaders.exists(name) && !initLuaShader(name)) {
			FlxG.log.warn('Shader $name is missing!');
			return new FlxRuntimeShader();
		}

		var arr:Array<String> = runtimeShaders.get(name);
		return new FlxRuntimeShader(arr[0], arr[1]);
		#else
		FlxG.log.warn("Platform unsupported for Runtime Shaders!");
		return null;
		#end
	}

	public function initLuaShader(name:String, ?glslVersion:Int = 120) {
		if (!ClientPrefs.data.shaders)
			return false;

		#if (MODS_ALLOWED && !flash && sys)
		if (runtimeShaders.exists(name)) {
			FlxG.log.warn('Shader $name was already initialized!');
			return true;
		}

		var foldersToCheck:Array<String> = [Paths.mods('shaders/')];
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Mods.currentModDirectory + '/shaders/'));

		for (mod in Mods.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/shaders/'));

		for (folder in foldersToCheck) {
			if (FileSystem.exists(folder)) {
				var frag:String = folder + name + '.frag';
				var vert:String = folder + name + '.vert';
				var found:Bool = false;
				if (FileSystem.exists(frag)) {
					frag = File.getContent(frag);
					found = true;
				} else
					frag = null;

				if (FileSystem.exists(vert)) {
					vert = File.getContent(vert);
					found = true;
				} else
					vert = null;

				if (found) {
					runtimeShaders.set(name, [frag, vert]);
					// trace('Found shader $name!');
					return true;
				}
			}
		}
		FlxG.log.warn('Missing shader $name .frag AND .vert files!');
		#else
		FlxG.log.warn('This platform doesn\'t support Runtime Shaders!');
		#end
		return false;
	}

	var camLerp:Float = 0.85;
	var camFocus:String = "";
	var camMovement:FlxTween;
	var camAngle:FlxTween;
	var daFunneOffsetMultiplier:Float = 15;
	var dadPos:Array<Float> = [0, 0];
	var bfPos:Array<Float> = [0, 0];
	var theCurrentZoom:Float = 0.9;
	var offsetOffsetMul:Float = 0;

	function triggerCamMovement(num:Float = 0) {
		if (camMovement != null) {
			camMovement.cancel();
		}
		if (camAngle != null) {
			camAngle.cancel();
		}

		var offsetCurrent:Float = daFunneOffsetMultiplier * (1 + (1 - theCurrentZoom));
		offsetCurrent += offsetOffsetMul;

		if (camFocus == 'bf') {
			switch (num) {
				case 2:
					camMovement = FlxTween.tween(camFollow, {y: bfPos[1] - offsetCurrent, x: bfPos[0]}, Conductor.crochet / 10000, {ease: FlxEase.circIn});
					camAngle = FlxTween.tween(FlxG.camera, {angle: 0}, Conductor.crochet / 2500, {ease: FlxEase.quadIn});
				case 3:
					camMovement = FlxTween.tween(camFollow, {x: bfPos[0] + offsetCurrent, y: bfPos[1]}, Conductor.crochet / 10000, {ease: FlxEase.circIn});
					camAngle = FlxTween.tween(FlxG.camera, {angle: 0.05}, Conductor.crochet / 2500, {ease: FlxEase.quadIn});
				case 1:
					camMovement = FlxTween.tween(camFollow, {y: bfPos[1] + offsetCurrent, x: bfPos[0]}, Conductor.crochet / 10000, {ease: FlxEase.circIn});
					camAngle = FlxTween.tween(FlxG.camera, {angle: 0}, Conductor.crochet / 2500, {ease: FlxEase.quadIn});
				case 0:
					camMovement = FlxTween.tween(camFollow, {x: bfPos[0] - offsetCurrent, y: bfPos[1]}, Conductor.crochet / 10000, {ease: FlxEase.circIn});
					camAngle = FlxTween.tween(FlxG.camera, {angle: -0.05}, Conductor.crochet / 2500, {ease: FlxEase.quadIn});
			}
		} else {
			switch (num) {
				case 2:
					camMovement = FlxTween.tween(camFollow, {y: dadPos[1] - offsetCurrent, x: dadPos[0]}, Conductor.crochet / 10000, {ease: FlxEase.circIn});
					camAngle = FlxTween.tween(FlxG.camera, {angle: 0}, Conductor.crochet / 2500, {ease: FlxEase.quadIn});
				case 3:
					camMovement = FlxTween.tween(camFollow, {x: dadPos[0] + offsetCurrent, y: dadPos[1]}, Conductor.crochet / 10000, {ease: FlxEase.circIn});
					camAngle = FlxTween.tween(FlxG.camera, {angle: 0.05}, Conductor.crochet / 2500, {ease: FlxEase.quadIn});
				case 1:
					camMovement = FlxTween.tween(camFollow, {y: dadPos[1] + offsetCurrent, x: dadPos[0]}, Conductor.crochet / 10000, {ease: FlxEase.circIn});
					camAngle = FlxTween.tween(FlxG.camera, {angle: 0}, Conductor.crochet / 2500, {ease: FlxEase.quadIn});
				case 0:
					camMovement = FlxTween.tween(camFollow, {x: dadPos[0] - offsetCurrent, y: dadPos[1]}, Conductor.crochet / 10000, {ease: FlxEase.circIn});
					camAngle = FlxTween.tween(FlxG.camera, {angle: -0.05}, Conductor.crochet / 2500, {ease: FlxEase.quadIn});
			}
		}
	}

	function checkFocus(?mode:String = 'default') {
		if (generatedMusic && PlayState.SONG.notes[Std.int(curStep / 16)] != null) {
			if (camFocus != "dad" && !PlayState.SONG.notes[Std.int(curStep / 16)].mustHitSection) {
				if (camMovement != null) {
					camMovement.cancel();
				}
				if (camAngle != null) {
					camAngle.cancel();
				}
				camFocus = 'dad';

				if (mode != 'snap') {
					camMovement = FlxTween.tween(camFollow, {x: dadPos[0], y: dadPos[1]}, camLerp, {ease: FlxEase.quintOut});
				} else {
					camFollow.x = dadPos[0];
					camFollow.y = dadPos[1];
					camMovement = FlxTween.tween(camFollow, {x: dadPos[0], y: dadPos[1]}, 0.001, {ease: FlxEase.quintOut});
				}
			}
			if (camFocus != "bf" && PlayState.SONG.notes[Std.int(curStep / 16)].mustHitSection) {
				if (camMovement != null) {
					camMovement.cancel();
				}
				if (camAngle != null) {
					camAngle.cancel();
				}
				camFocus = 'bf';

				if (mode != 'snap') {
					camMovement = FlxTween.tween(camFollow, {x: bfPos[0], y: bfPos[1]}, camLerp, {ease: FlxEase.quintOut});
				} else {
					camFollow.x = bfPos[0];
					camFollow.y = bfPos[1];
					camMovement = FlxTween.tween(camFollow, {x: bfPos[0], y: bfPos[1]}, 0.001, {ease: FlxEase.quintOut});
				}
			}
		}
	}

	public function getCamOffsets(?char:String) {
		switch (char) {
			case 'bf':
				bfPos[0] = boyfriend.getMidpoint().x - 100;
				bfPos[1] = boyfriend.getMidpoint().y - 100;

			case 'dad':
				dadPos[0] = dad.getMidpoint().x + 150;
				dadPos[1] = dad.getMidpoint().y - 100;

			default:
				// dad shit
				dadPos[0] = dad.getMidpoint().x + 150;
				dadPos[1] = dad.getMidpoint().y - 100;

				// bf shit
				bfPos[0] = boyfriend.getMidpoint().x - 100;
				bfPos[1] = boyfriend.getMidpoint().y - 100;

				bfPos[0] -= boyfriend.cameraPosition[0] - boyfriendCameraOffset[0];
				bfPos[1] += boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];
				dadPos[0] += dad.cameraPosition[0] + opponentCameraOffset[0];
				dadPos[1] += dad.cameraPosition[1] + opponentCameraOffset[1];
		}
	}
	#end
}
