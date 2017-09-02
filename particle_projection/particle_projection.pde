// ==================================================
// this sketch recieves OSC and draws particles
// ==================================================

import oscP5.*;  
import netP5.*;
import blobDetection.*;
import processing.video.*;
// ==================================================
// OSC globals
// ==================================================
OscP5 oscP5;
NetAddress myRemoteLocation;
// ==================================================
// blob globals
// ==================================================
PImage img;
boolean newFrame=false;
// ==================================================
// particle field globals
// ==================================================
float incr = 0.1;
float start = 0.0;
float scale = 10;
int rows, cols;
float zoff = 0.0;
ArrayList<Particle> particles;
PVector[] flowfield;
ArrayList<BlobOSC> blobDetails;
int numParticles = 10000;
float maxDist = 100;
int density;
float curX = 0.0;
float curY = 0.0;
int x1, x2, x3, x4;
int y1, y2, y3, y4;

PGraphics offscreen;


void setup() {
  size(1000, 1000, P2D); //2100 for 4K monitor
  background(0);

  cols = floor(width/scale);
  rows = floor(height/scale);
  generate(numParticles);

  //start up OSC
  oscP5 = new OscP5(this, 57120);   //listening on
  myRemoteLocation = new NetAddress("127.0.0.1", 57121);  //speaking to


  blobDetails = new ArrayList<BlobOSC>();


  x1 = 200;
  x2 = width-200;
  x3 = width-200;
  x4 = 200;

  y1 = 200;
  y2 = 200;
  y3 = height-200;
  y4 = height-200;

  offscreen = createGraphics(width, height);
}

void draw() {


  /*
   * generate the direction of flow per cell
   * according the Perlin noise and store it
   * however if the particles are close to the mouse
   * attract or repel from mouse position
   */

  float yoff = 0;
  for (int x = 0; x < cols; x++) {
    float xoff=0;
    for (int y=0; y<rows; y++) {

      int index = x + y * cols;   
      //add blob interaction
      PVector dir = new PVector(0, 0);
      for (BlobOSC bo:blobDetails) {
        if(bo==null){ continue; } //lol why???
        curX = bo.x;
        curY = bo.y;
        float dist = dist(curX, curY, x*scale, y*scale);
        if (dist < maxDist) {
          PVector newForce = new PVector(x*scale-curX, y*scale-curY);
          dir = dir.add(newForce);
        }
      }
      float angle = noise(xoff, yoff, zoff)* 2 * PI * 6;
      PVector base = PVector.fromAngle(angle);
      base.setMag(0.2);
      flowfield[index]= base.add(dir);
      //showField(x,y,base.add(dir));
      xoff += incr;
    }
    yoff+=incr;
  }
  zoff+=0.001;

  /*
   * Draw the flow field offscreen
   */

  offscreen.beginDraw();
  offscreen.fill(0,20);
  offscreen.rect(0, 0, width, height);

  showParticles();
  identifyBlob();
  offscreen.stroke(255);
  offscreen.strokeWeight(10);
  offscreen.line(0,0,width,0);
  offscreen.line(width,0,width,height);
  offscreen.line(width,0,width,height);
  offscreen.line(0,height,0,0);
  offscreen.fill(255);
  //offscreen.rect(width-1150,height-1150,width,height);
  offscreen.endDraw();

  sendBlobOSC();
  
  /* 
   * load the flow field as a texture on a plane that can be manipulated
   */
  
  fill(0);//, 30);
  rect(0, 0, width, height);
  beginShape();
  texture(offscreen);
  vertex(x1, y1, 0, 0);
  vertex(x2, y2, 1000, 0);
  vertex(x3, y3, 1000, 1000);
  vertex(x4, y4, 0, 1000);
  endShape();


  //draw webcam preview
  //image(cam, 0, 0, width/5, height/5);
}
void oscEvent(OscMessage theOscMessage) {

  theOscMessage.print();
  float blobX = theOscMessage.get(0).floatValue();
  float blobY = theOscMessage.get(1).floatValue();
  float blobDen = theOscMessage.get(2).floatValue();
  println(blobX+" "+blobY+" "+blobDen);
  blobDetails = new ArrayList<BlobOSC>();
  if(blobX>0.0 && blobY>0.0){
    BlobOSC newBlob =new BlobOSC(blobX,blobY,blobDen);
    blobDetails.add(newBlob);
  }
}





void keyPressed() {
  if (key == 'q') {
    x1 = mouseX;
    y1 = mouseY;
  }
  if (key == 'w') {
    x2 = mouseX;
    y2 = mouseY;
  }
  if (key == 'e') {
    x3 = mouseX;
    y3 = mouseY;
  }
  if (key == 'r') {
    x4 = mouseX;
    y4 = mouseY;
  }
}
void generate(int num) {
  particles = new ArrayList<Particle>();
  flowfield = new PVector[rows*cols];
  for (int i=0; i<num; i++) {
    particles.add(new Particle());
  }
}

void showParticles() {
  for (Particle p : particles) {   
    p.follow();
    p.update();
    p.show(offscreen);
    p.edges();
  }
}

void showField(int x, int y, PVector force) {
  pushMatrix();
  translate(x*scale, y*scale);
  rotate(force.heading()); //rotate the line based on vector angle
  stroke(255);
  line(0, 0, scale, 0);
  popMatrix();
}


void identifyBlob() {
  for (int i =0; i <blobDetails.size(); i++) {
    offscreen.textSize(32);
    BlobOSC bo = blobDetails.get(i);
    offscreen.fill(255, 0, 0);
    offscreen.text(i, bo.x, bo.y);
    offscreen.noFill();
    offscreen.strokeWeight(3);
    offscreen.ellipse(bo.x, bo.y,maxDist*2,maxDist*2);
  }
}



void sendBlobOSC() {
  OscMessage newMessage = new OscMessage("o");
  for (int i =0; i <2; i++) {
    if (i>=blobDetails.size()) {
      newMessage.add(0);
      newMessage.add(0);
      newMessage.add(0);
    } else {
      BlobOSC bo = blobDetails.get(i);
      newMessage.add(bo.x);
      newMessage.add(bo.y);
      newMessage.add(bo.density);
    }
  }
  newMessage.add(1); //chaos level
  oscP5.send(newMessage, myRemoteLocation);
}