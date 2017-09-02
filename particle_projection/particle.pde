class Particle{
  PVector pos = new PVector(random(width),random(height));
  PVector vel = new PVector(0,0);
  PVector acc = new PVector(0,0);
  float maxSpeed = 2;

  void update(){
    vel.add(acc);
    vel.limit(maxSpeed);
    pos.add(vel);
    acc.mult(0); //reset acceleration
  }
  
  void applyForce(PVector force){
      acc.add(force);
  }
  
  void show(PGraphics pg){
    pg.stroke(255);
    pg.strokeWeight(7);
    pg.point(pos.x,pos.y);
  }
  

  
  void edges(){
     if(pos.x >= width){ pos.x = 0; }
     if(pos.x < 0){ pos.x = width; }
     if(pos.y >= height){ pos.y = 0; }
     if(pos.y < 0){ pos.y = height; }
  }
  
  void follow(){
    int x = floor(pos.x / scale);
    int y = floor(pos.y / scale);
    
    //prevent index from getting out of bounds (some bug?)
    if(x>=width/scale) x--;
    if(y>=height/scale) y=49;
    
    int index = x + y * cols;
    PVector force = flowfield[index];
    applyForce(force);
  }
}