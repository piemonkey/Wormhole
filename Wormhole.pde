//The MIT License (MIT) - See Licence.txt for details

//Copyright (c) 2013 Mick Grierson, Matthew Yee-King, Marco Gillies


import org.jbox2d.util.nonconvex.*;
import org.jbox2d.dynamics.contacts.*;
import org.jbox2d.testbed.*;
import org.jbox2d.collision.*;
import org.jbox2d.common.*;
import org.jbox2d.dynamics.joints.*;
import org.jbox2d.p5.*;
import org.jbox2d.dynamics.*;

// audio stuff
Maxim maxim;
AudioPlayer droidSound, wallSound, music;
AudioPlayer[] crateSounds;
float beatThreshold = 0.31;
int beatTimeout = 15;
int wait = 0;
int nextCrateSound = 0;

// Background wormhole stuff
float magnify = 20;
float rotation = 0;
float radius = 0;
int elements = 100;
float baseColour = 0.0;
float spacing;

Physics physics;
Body droid;
Body [] crates = new Body[0];
CollisionDetector detector; 

int crateSize = 80;
int ballSize = 60;

PImage crateImage, ballImage;

int score = 0;
boolean gameOver = false;

// this is used to remember that the user 
// has triggered the audio on iOS... see mousePressed below
boolean userHasTriggeredAudio = false;

void setup() {
  size(1024, 768);
  frameRate(60);

  crateImage = loadImage("crate.jpeg");
  ballImage = loadImage("tux_droid.png");
  imageMode(CENTER);
  
  // Set up for wormhole
  colorMode(HSB);
  spacing = TWO_PI/elements;


  /*
   * Set up a physics world. This takes the following parameters:
   * 
   * parent The PApplet this physics world should use
   * gravX The x component of gravity, in meters/sec^2
   * gravY The y component of gravity, in meters/sec^2
   * screenAABBWidth The world's width, in pixels - should be significantly larger than the area you intend to use
   * screenAABBHeight The world's height, in pixels - should be significantly larger than the area you intend to use
   * borderBoxWidth The containing box's width - should be smaller than the world width, so that no object can escape
   * borderBoxHeight The containing box's height - should be smaller than the world height, so that no object can escape
   * pixelsPerMeter Pixels per physical meter
   */
  physics = new Physics(this, width, height, 0, 0, width*2, height*2, width, height, 100);
  physics.setCustomRenderingMethod(this, "myCustomRenderer");
  physics.setDensity(10.0);

  float defaultRestitution = physics.getRestitution();
  physics.setRestitution(1.0);
  droid = physics.createCircle(width/2, height/2, ballSize/2);
  physics.setRestitution(defaultRestitution);

  // sets up the collision callbacks
  detector = new CollisionDetector (physics, this);

  maxim = new Maxim(this);
  droidSound = maxim.loadFile("droid.wav");
  wallSound = maxim.loadFile("wall.wav");

  droidSound.setLooping(false);
  droidSound.volume(0.25);
  wallSound.setLooping(false);
  wallSound.volume(0.25);
  // Array of crate sounds to be used as a pool
  crateSounds = new AudioPlayer[10];
  for (int i = 0; i < crateSounds.length; i++) {
    crateSounds[i] = maxim.loadFile("crate2.wav");
    crateSounds[i].setLooping(false);
    crateSounds[i].volume(0.15);
  }

  music = maxim.loadFile("51239__rutgermuller__8-bit-electrohouse.wav");
  music.setLooping(true);
  music.setAnalysing(true);
}

void draw() {
  if (!gameOver) {
    background(0);
    float speed = constrain(0.8 + score * 0.001, 0.8, 2.0);
    music.speed(speed);
    music.play();
    if (wait < 0) {
      float power = music.getAveragePower();
      if (power > beatThreshold) {
        int x = random(crateSize, width - crateSize);
        int y = random(crateSize, height - crateSize);
        Body newCrate = physics.createRect(x - crateSize/2,
                                          y - crateSize/2,
                                          x + crateSize/2,
                                          y + crateSize/2);
        crates = (Body[]) append(crates, newCrate);
        Vec2 dir = new Vec2 (random(-30, 30), random(-30, 30));
        newCrate.applyImpulse(dir, newCrate.getWorldCenter());
        wait = beatTimeout;
      }
    } else {
      wait--;
    }
    
    // Draw wormhole
    radius = 1.5;//map(mouseX, 0, width, 0, 3);//random(0, 2);//map(mouseX, 0, width, 0, 10);
    rotation = 0;//map(mouseY, 0, height, -1, 1);//random(0, 2);map(mouseY, 0, height, 0, 10);
    float xPerElement = (mouseX - width*0.5)/elements;
    float yPerElement = (mouseY - height*0.5)/elements;
    baseColour = (baseColour + 3 * speed) % 256;
    noFill();
    strokeWeight(2);
    for (int i = 0; i < elements;i++) {
        stroke((baseColour + i*2) % 255,255,255);
        pushMatrix();
        // Each circle is drawn slightly more pushed towards the mouse
        translate(width * 0.5 + xPerElement * i, height * 0.5 + yPerElement * i);
        rotate(spacing*i*rotation);
        translate(sin(spacing*i*radius)*magnify, 0);
        ellipse(0,0,2*i,2*i);
        popMatrix();
    }
  
    fill(0, 255, 255);
    textSize(12);
    textAlign(LEFT);
    text("Score: " + score, 20, 20);
  } else {
    music.stop();
    fill(0, 255, 255);
    textSize(100);
    textAlign(CENTER);
    text("GAME OVER\nScore: " + score, width/2, height/2);
    for (Body crate : crates) {
      physics.removeBody(crate);
    }
    crates = new Body[0];
    droid.setLinearVelocity(new Vec2(0, 0));
  }
}

/** on iOS, the first audio playback has to be triggered
* directly by a user interaction
* so the first time they tap the screen, 
* we play everything once
* we could be nice and mute it first but you can do that... 
*/
void mousePressed() {
  if (!userHasTriggeredAudio) {
    music.play();
    droidSound.play();
    wallSound.play();
    for (int i = 0; i < crateSounds.length; i++) {
      crateSounds[i].play();
    }
    userHasTriggeredAudio = true;
  }
}

void mouseClicked() {
  if (gameOver) {
    score = 0;
    music.cue();
    gameOver = false;
  }
}

// this function renders the physics scene.
// this can either be called automatically from the physics
// engine if we enable it as a custom renderer or 
// we can call it from draw
void myCustomRenderer(World world) {
  if (!gameOver) {
    // get the droids position and rotation from
    // the physics engine and then apply a translate 
    // and rotate to the image using those values
    // (then do the same for the crates)
    Vec2 worldDroidPos = droid.getWorldCenter();
    Vec2 screenDroidPos = physics.worldToScreen(worldDroidPos);
    float droidAngle = physics.getAngle(droid);
    pushMatrix();
    translate(screenDroidPos.x, screenDroidPos.y);
    rotate(-radians(droidAngle));
    image(ballImage, 0, 0, ballSize, ballSize);
    popMatrix();
  
    Vec2 wormholeCentre = new Vec2(mouseX, mouseY);
    Vec2 droidToWorm = wormholeCentre.sub(screenDroidPos);
    if (droidToWorm.lengthSquared() < 1000) {
      gameOver = true;
    } else {
      droidToWorm.normalize();
      droid.applyImpulse(droidToWorm.mul(0.1), worldDroidPos);
    }
    // Crate to remove, can only be one as collisions prevent more than one getting close
    int remove = -1;
    for (int i = 0; i < crates.length; i++)
    {
      Vec2 worldCenter = crates[i].getWorldCenter();
      Vec2 cratePos = physics.worldToScreen(worldCenter);
      Vec2 directionToWormhole = wormholeCentre.sub(cratePos);
      if (directionToWormhole.lengthSquared() < 1000) {
        remove = i;
      } else {
        float scale = 100 / directionToWormhole.lengthSquared();
        float crateAngle = physics.getAngle(crates[i]);
        pushMatrix();
        translate(cratePos.x, cratePos.y);
        rotate(-crateAngle);
        image(crateImage, 0, 0, crateSize, crateSize);
        popMatrix();
    
        crates[i].applyImpulse(directionToWormhole.mul(scale), worldCenter);
      }
    }
    if (remove >= 0) {
      score++;
      physics.removeBody(crates[remove]);
      crates = removeBody(crates, remove);
    }
  }
}

// This method gets called automatically when 
// there is a collision
void collision(Body b1, Body b2, float impulse)
{
  if (impulse > 25.0){ //only play a sound if the force is strong enough ... otherwise we get too many sounds playing at once
  
    // test for droid
    if (b1.getMass() == 0 || b2.getMass() == 0) {// b1 or b2 are walls
      // wall sound
      //println("wall "+(impulse / 1000));
      wallSound.cue(0);
      wallSound.speed(impulse / 1000);// 
      wallSound.play();
    }
    if (b1 == droid || b2 == droid) { // b1 or b2 are the droid
      // droid sound
      //println("droid");
      droidSound.cue(0);
      droidSound.speed(impulse / 1000);
      droidSound.play();
    }
    for (int i=0; i < crates.length; i++) {
      if (b1 == crates[i] || b2 == crates[i]) {// its a crate
        crateSounds[nextCrateSound].cue(0);
        crateSounds[nextCrateSound].speed(0.25 + (impulse / 250));// 10000 as the crates move slower??
        crateSounds[nextCrateSound].play();
        nextCrateSound = (nextCrateSound + 1) % crateSounds.length;
      }
    }
  
  }
  //
}

Body[] removeBody(Body[] array, int index) {
  Body[] ret = new Body[array.length - 1];
  int count = 0;
  for (int i = 0; i < array.length; i++) {
    if (i != index) {
      ret[count] = array[i];
      count++;
    }
  }
  return ret;
}
      

