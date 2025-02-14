package overworld;

import overworld.*;
import backend.MusicBeatState;
import overworld.scenes.*;
import backend.ObjectBlendMode;
import flixel.FlxBasic;
import flixel.FlxObject;
import objects.Soulmeter;
import substates.*;

class OverworldManager extends MusicBeatState {
	public static var instance:OverworldManager;
	public static var switching:Bool = false;

	public static var postSongDialogue:String = '';

	public var player:Player;
	public var scene:BaseScene;

	public var camFollow:FlxObject;
	public var camHUD:FlxCamera;
	public var camDIALOG:FlxCamera;
	public var camCHARM:FlxCamera;
	public var dubious:FlxCamera;

	public var dialogue:Dialogue;
	public var soulMeter:Soulmeter;

	var black:FlxSprite;

	public var campos = [0.0, 0.0];

	var thebop:FlxSound;
	var shouldplay:Bool = false;

	public function regenSoulMeter() {
		var oldSoulMeter = soulMeter;
		soulMeter = new Soulmeter(22, 30, 7, camHUD);
		insert(0, soulMeter);
		// trace("soulmeterPosition " + FlxG.state.members.indexOf(soulMeter));
		soulMeter.backBoard.animation.play("appear");
		soulMeter.showMasks();

		// to keep it cached
		if (oldSoulMeter != null) {
			oldSoulMeter.destroy();
			remove(oldSoulMeter, true);
		}
	}

	function cameraInit() {
		FlxG.camera.zoom = 0.61;
		// HUD
		camHUD = new FlxCamera();
		FlxG.cameras.add(camHUD, false);
		camHUD.bgColor.alpha = 0;

		soulMeter = new Soulmeter(22, 30, 7, camHUD);
		add(soulMeter);
		// trace("soulmeterPosition " + FlxG.state.members.indexOf(soulMeter));
		soulMeter.backBoard.animation.play("appear");
		soulMeter.showMasks();

		// DIALOG
		camDIALOG = new FlxCamera();
		FlxG.cameras.add(camDIALOG, false);
		camDIALOG.bgColor.alpha = 0;

		dialogue = new Dialogue();
		dialogue.screenCenterXY();
		dialogue.y -= 200;
		dialogue.x += 10;
		dialogue.cameras = [camDIALOG];
		add(dialogue);

		black = new FlxSprite(0, 0).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
		black.cameras = [camDIALOG];
		black.screenCenterXY();
		add(black);
		black.alpha = 1;

		camCHARM = new FlxCamera();
		FlxG.cameras.add(camCHARM, false);
		camCHARM.bgColor.alpha = 0;

		dubious = new FlxCamera();
		FlxG.cameras.add(dubious, false);
		dubious.setSize(1920, 1080);
		dubious.setPosition(-200, -120);
		dubious.bgColor.alpha = 0;

		// FOLLOW
		camFollow = new FlxObject(0, 0, 1, 1);
		FlxG.camera.follow(camFollow, LOCKON);
	}

	public static var playerLocation1:String = "Dirtmouth";
	public static var playerLocation2:String = "Dirtmouth";
	public static var playerLocation3:String = "Dirtmouth";
	public static var playerLocation4:String = "Dirtmouth";

	public static function getplayerLocation() {
		var goob = "Dirtmouth";
		switch (DataSaver.saveFile) {
			case 1: goob = playerLocation1;
			case 2: goob = playerLocation2;
			case 3: goob = playerLocation3;
			case 4: goob = playerLocation4;
		}
		return goob;
	}

	public static function setplayerLocation(goob:String) {
		switch (DataSaver.saveFile) {
			case 1: playerLocation1 = goob;
			case 2: playerLocation2 = goob;
			case 3: playerLocation3 = goob;
			case 4: playerLocation4 = goob;
		}
	}

	override function create() {
		#if desktop
		DiscordClient.changePresence("In the Overworld", null);
		#end

		// INITIALIZE
		instance = this;
		persistentUpdate = persistentDraw = true;
		cameraInit();

		FlxG.camera.setFilters([]);

		if (getplayerLocation() == "Dirtmouth") {
			scene = new Dirtmouth();
			scene.create(OverworldManager.postSongDialogue);
		} else {
			scene = new SlyShop();
			scene.create(OverworldManager.postSongDialogue);
		}

		player = new Player(0, 0);
		player.screenCenterXY();
		player.y += FlxG.height / 3 - 1;
		add(player);

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		thebop = FlxG.sound.load(Paths.sound('dirtmouthSlyLoop', 'hymns'));
		thebop.looped = true;

		FlxG.sound.playMusic(Paths.sound('dirtmouthLoop', "hymns"));
		thebop.play(true);

		if (getplayerLocation() == "Dirtmouth") {
			FlxG.sound.music.volume = 0;
			FlxG.sound.music.fadeIn(4, 0, .8);
			thebop.volume = 0;

			shouldplay = false;
		} else {
			FlxG.sound.music.volume = 0;
			FlxG.sound.music.fadeIn(2, 0, .8);
			thebop.volume = 0;
			thebop.fadeIn(4, 0, 1);
			player.screenCenterXY();
			player.y += FlxG.height / 3 - 1;
			player.flipX = true;

			shouldplay = true;
			setplayerLocation("Dirtmouth");
		}

		scene.variableInitialize();
		scene.createPost();

		FlxTween.tween(black, {alpha: 0}, 1.5, {ease: FlxEase.quadOut});
		/*
			new FlxTimer().start(2, function(tmr:FlxTimer) {
				player.animation.play("benchdismount", true);
			});
		 */

		// dirtmouthSlyLoop

		// switchScenery(new Shop());
	}

	public function switchScenery(scene2:BaseScene) {
		if (switching)
			return;

		switching = true;
		// Controls.acceptElapsed = 0.016 * 20; // approx. twenty frames of disabled enter key
		// Controls.acceptTimer = true;

		if (scene.slyshop && scene.exitWalking) {
			OverworldManager.instance.player.crippleStatus(true, "weird tween when leaving");
			// OverworldManager.instance.player.xNote = "tweenLeave";
			FlxTween.tween(player, {x: player.x - 5 * 35}, .66, {ease: FlxEase.quadOut});
		}
		FlxTween.tween(black, {alpha: 1}, .5, {
			ease: FlxEase.quadOut,
			onComplete: function(twn:FlxTween) {
				new FlxTimer().start(1, function(tmr:FlxTimer) {
					var slyshopexit:Bool = false;

					if (!scene.slyshop) {
						thebop.volume = 0;
						thebop.fadeIn(2, 0, .8);
						FlxG.sound.music.fadeIn(2, .8, .6);
						thebop.time = FlxG.sound.music.time;
						shouldplay = true;
					} else {
						slyshopexit = true;
						thebop.fadeOut(4, 0);
						FlxG.sound.music.fadeIn(2, .6, .8);
						shouldplay = false;
					}
					trace(scene.slyshop);
					FlxG.camera.setFilters([]);
					instance.forEach(function(bigballs:FlxBasic) {
						if (!(bigballs == camHUD || bigballs == soulMeter || bigballs == camDIALOG || bigballs == dialogue || bigballs == camFollow || bigballs == black))
							bigballs.destroy();
					});
					scene.destroy();
					scene = scene2;
					scene.create();

					player = new Player(0, 0);
					player.screenCenterXY();
					player.y += FlxG.height / 3 - 1;
					OverworldManager.instance.player.crippleStatus(true, "fade black tween");
					add(player);

					scene.variableInitialize();
					scene.createPost();
					if (slyshopexit) {
						player.x = -142.09;
						player.flipX = true;
					}

					new FlxTimer().start(1, function(tmr:FlxTimer) {
						FlxTween.tween(black, {alpha: 0}, 1.5, {ease: FlxEase.quadOut});
						new FlxTimer().start(1.4, function(tmr:FlxTimer) {
							player.crippleStatus(postSongDialogue != '', "cripple on scene change?");
							OverworldManager.postSongDialogue = "";
							switching = false;
						});
					});
				});
			}
		});
	}

	override function update(elapsed:Float) {
		// UPDATING SPRITES
		handleDebug(); // remove when super.update is added
		scene.update(elapsed);
		player.update(elapsed);
		soulMeter.update(elapsed);
		dialogue.update(elapsed);

		if (thebop != null) {
			thebop.update(elapsed);
		}

		// LERPING VALUES
		var lerpVal:Float = CoolUtil.boundTo(elapsed * 7.2, 0, 1);
		if (campos[1] == 0.0) {
			var pp = player.getMidpoint();
			camFollow.x = FlxMath.lerp(camFollow.x, FlxMath.bound(pp.x, scene.stageproperties.minCam, scene.stageproperties.maxCam), lerpVal);
			camFollow.y = FlxMath.lerp(camFollow.y, pp.y - 225, lerpVal);
			pp.put();
		} else {
			camFollow.x = FlxMath.lerp(camFollow.x, campos[0], lerpVal);
			camFollow.y = FlxMath.lerp(camFollow.y, campos[1], lerpVal);
		}

		// BOX PLAYER
		player.x = Math.max(scene.stageproperties.minX, player.x);
		player.x = Math.min(scene.stageproperties.maxX, player.x);

		if (controls.BACK && OverworldManager.instance.scene.inshop == false) {
			if (this.subState == null) {
				openPauseMenu();
			}
		}

		if (FlxG.sound.music.playing == true) {
			if (thebop.playing == false && shouldplay) {
				thebop.resume();
				thebop.time = FlxG.sound.music.time;
			}
			// thebop.time = FlxG.sound.music.time;
		}
	}

	function openPauseMenu() {
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		persistentDraw = true;

		if (FlxG.sound.music != null) {
			FlxG.sound.music.pause();
			thebop.pause();
		}
		openSubState(new PauseSubState(true));
	}
}
