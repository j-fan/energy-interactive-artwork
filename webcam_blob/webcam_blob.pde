// ==================================================
// this sketch does blob detection with a webcam
// and sends the result via OSC
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
// webcam and blob globals
// ==================================================
Capture cam;
BlobDetection blobDetect;
PImage img;
boolean newFrame=false;
ArrayList<BlobOSC> blobDetails;
float maxDist = 150;
// ==================================================
// projection mapping mechanic
// ==================================================
int x1, x2, x3, x4;
int y1, y2, y3, y4;
PImage preview;
int cropX=600; //600
int cropY=600;  //600
int cropSize=800; //800

void setup() {
  size(1000, 1000, P2D); //2000
  background(0);
  //start up OSC
  oscP5 = new OscP5(this, 12000);   //listening on
  myRemoteLocation = new NetAddress("127.0.0.1", 57120);  //speaking to
  //http://www.sojamo.de/libraries/oscP5/examples/oscP5bundle/oscP5bundle.pde 

  //start up webcam
  String[] cameras = Capture.list();
  for (int i = 0; i < cameras.length; i++) {
      println(i + " " +cameras[i]);
  }
  cam = new Capture(this, 160, 120,cameras[10]);
  cam.start();
  preview = new PImage(300, 300);

  //start up blob detection
  blobDetect = new BlobDetection(cropSize/2,cropSize/2);
  blobDetect.setPosDiscrimination(true);
  blobDetect.setThreshold(0.15f); // 0.95 default

  blobDetails = new ArrayList<BlobOSC>();

  x1 = 0;
  x2 = width;
  x3 = width;
  x4 = 0;

  y1 = 0;
  y2 = 0;
  y3 = height;
  y4 = height;
}

void draw() {
  background(0);
  /* 
   * whenever we recieve a new frame from the webcam, copy to preview
   */
  if (newFrame) {
    newFrame=false;
    preview.copy(cam, 0, 0, cam.width, cam.height, 0, 0, preview.width, preview.height);
  }
  /* 
   * load the webcam feed as a texture on a plane that can be manipulated
   */
  fill(0);
  rect(0, 0, width, height);
  beginShape();
  texture(preview);
  vertex(x1, y1, 0, 0);
  vertex(x2, y2, preview.width, 0);
  vertex(x3, y3, preview.width, preview.height);
  vertex(x4, y4, 0, preview.height);
  endShape();
  /*
   * copy screen pixels to img
   */
  img = new PImage(width, height);
  loadPixels();
  for (int i=0; i<width*height; i++) {
    img.pixels[i] = pixels[i];
  }
  
  /*
   * crop the preview to the crop square
   */
  noFill();
  stroke(0, 255, 0);
  strokeWeight(3);
  rect(cropX, cropY, cropSize, cropSize);
  PImage crop = new PImage(cropSize,cropSize);
  crop.copy(img,cropX,cropY,cropSize,cropSize,0,0,cropSize,cropSize);
  crop.resize(cropSize/2, cropSize/2);
  /* 
   * do blob detection on the crop 
   */
  fastblur(crop, 2);
  blobDetect.computeBlobs(crop.pixels);
  /*
   * do blob tracking
   */
  updateBlobDetails();
  blobAging();

  /*
   * show debugging output to screen
   */
  identifyBlob();
  drawBlobsAndEdges(true, true);

  /*
   * send blob osc message
   */

  sendBlobOSC();
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
void oscEvent(OscMessage theOscMessage) {
  theOscMessage.print();
}
void updateBlobDetails() {
  for (int n=0; n<blobDetect.getBlobNb(); n++) {
    Blob b=blobDetect.getBlob(n);
    int curX = floor(b.xMin*width + b.w*width / 2);
    int curY = floor(b.yMin*height + b.h*height / 2);
    addNewBlobDetails(curX, curY);
  }
}

/*
 * perform blob recognition & tracking
 */
void addNewBlobDetails(float newX, float newY) {
  BlobOSC newB = new BlobOSC(newX, newY);
  boolean replaced = false;
  int i=0;
  int replaceI = 0;
  for (i =0; i <blobDetails.size(); i++) {
    BlobOSC bo = blobDetails.get(i);
    bo.density = 0;
    if (bo.isSame(newB)) {
      replaced = true;
      replaceI = i;
      break;
    }
  }
  if (replaced == true) {
    blobDetails.add(replaceI, newB);
  } else {
    blobDetails.add(newB);
  }
}
/*
 * Reduce the lifespan of blobs so that ones that don't exist anymore can be killed off
 */
void blobAging() {
  ArrayList<BlobOSC> toKill = new ArrayList<BlobOSC>();
  for (int i =0; i <blobDetails.size(); i++) {
    BlobOSC bo = blobDetails.get(i);
    bo.life --;
    if (bo.life <= 0) {
      toKill.add(bo);
    }
  }
  // kill off blobs that haven't been matched in a while
  for (BlobOSC dead : toKill) {
    blobDetails.remove(dead);
  }
}

void identifyBlob() {
  for (int i =0; i <blobDetails.size(); i++) {
    textSize(32);
    BlobOSC bo = blobDetails.get(i);
    fill(255, 0, 0);
    text(i, bo.x/width*cropSize+cropX, bo.y/height*cropSize+cropY);
  }
}

void findBlobDensities(float x, float y) {
  for (int i =0; i <blobDetails.size(); i++) {
    BlobOSC bo = blobDetails.get(i);
    float dist = dist(bo.x, bo.y, x, y);
    if (dist < maxDist) {
      bo.density ++;
    }
  }
}

void sendBlobOSC() {
  OscMessage newMessage = new OscMessage("o");
  for (int i =0; i <1; i++) {
    if (i>=blobDetails.size()) {
      newMessage.add(0.0);
      newMessage.add(0.0);
      newMessage.add(0.0);
    } else {
      BlobOSC bo = blobDetails.get(i);
      newMessage.add(bo.x/width * 1000);
      newMessage.add(bo.y/height * 1000);
      newMessage.add(bo.density);
    }
  }
  oscP5.send(newMessage, myRemoteLocation);
}

// ==================================================
// adapted from the blob detection library example
// ==================================================

void drawBlobsAndEdges(boolean drawBlobs, boolean drawEdges)
{
  noFill();
  Blob b;
  EdgeVertex eA, eB;
  for (int n=0; n<blobDetect.getBlobNb(); n++) {
    b=blobDetect.getBlob(n);
    if (b!=null) {
      // Edges
      if (drawEdges) {
        strokeWeight(3);
        stroke(0, 255, 0);
        for (int m=0; m<b.getEdgeNb(); m++)
        {
          eA = b.getEdgeVertexA(m);
          eB = b.getEdgeVertexB(m);
          if (eA !=null && eB !=null)
            line(
              eA.x*cropSize+cropX, eA.y*cropSize+cropY, 
              eB.x*cropSize+cropX, eB.y*cropSize+cropY
              );
        }
      }

      // Blobs
      if (drawBlobs) {
        strokeWeight(1);
        stroke(255, 0, 0);
        rect(b.xMin+cropX, b.yMin+cropY, b.w+cropX, b.h+cropY);
      }
    }
  }
}

void captureEvent(Capture cam)
{
  cam.read();
  newFrame = true;
}

// ==================================================
// Super Fast Blur v1.1
// by Mario Klingemann 
// <http://incubator.quasimondo.com>
// ==================================================
void fastblur(PImage img, int radius)
{
  if (radius<1) {
    return;
  }
  int w=img.width;
  int h=img.height;
  int wm=w-1;
  int hm=h-1;
  int wh=w*h;
  int div=radius+radius+1;
  int r[]=new int[wh];
  int g[]=new int[wh];
  int b[]=new int[wh];
  int rsum, gsum, bsum, x, y, i, p, p1, p2, yp, yi, yw;
  int vmin[] = new int[max(w, h)];
  int vmax[] = new int[max(w, h)];
  int[] pix=img.pixels;
  int dv[]=new int[256*div];
  for (i=0; i<256*div; i++) {
    dv[i]=(i/div);
  }

  yw=yi=0;

  for (y=0; y<h; y++) {
    rsum=gsum=bsum=0;
    for (i=-radius; i<=radius; i++) {
      p=pix[yi+min(wm, max(i, 0))];
      rsum+=(p & 0xff0000)>>16;
      gsum+=(p & 0x00ff00)>>8;
      bsum+= p & 0x0000ff;
    }
    for (x=0; x<w; x++) {

      r[yi]=dv[rsum];
      g[yi]=dv[gsum];
      b[yi]=dv[bsum];

      if (y==0) {
        vmin[x]=min(x+radius+1, wm);
        vmax[x]=max(x-radius, 0);
      }
      p1=pix[yw+vmin[x]];
      p2=pix[yw+vmax[x]];

      rsum+=((p1 & 0xff0000)-(p2 & 0xff0000))>>16;
      gsum+=((p1 & 0x00ff00)-(p2 & 0x00ff00))>>8;
      bsum+= (p1 & 0x0000ff)-(p2 & 0x0000ff);
      yi++;
    }
    yw+=w;
  }

  for (x=0; x<w; x++) {
    rsum=gsum=bsum=0;
    yp=-radius*w;
    for (i=-radius; i<=radius; i++) {
      yi=max(0, yp)+x;
      rsum+=r[yi];
      gsum+=g[yi];
      bsum+=b[yi];
      yp+=w;
    }
    yi=x;
    for (y=0; y<h; y++) {
      pix[yi]=0xff000000 | (dv[rsum]<<16) | (dv[gsum]<<8) | dv[bsum];
      if (x==0) {
        vmin[y]=min(y+radius+1, hm)*w;
        vmax[y]=max(y-radius, 0)*w;
      }
      p1=x+vmin[y];
      p2=x+vmax[y];

      rsum+=r[p1]-r[p2];
      gsum+=g[p1]-g[p2];
      bsum+=b[p1]-b[p2];

      yi+=w;
    }
  }
}