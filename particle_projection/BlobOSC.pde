class BlobOSC{
   float x;
   float y;
   float density;
   int isSameDist = 100;
   int life;
   BlobOSC(float x,float y,float density){
       this.x = x;
       this.y =y;
       this.density = density;
       life =2;
   }
   //Do some blob tracking
   boolean isSame(BlobOSC b){
     return (abs(b.x-x) < isSameDist && abs(b.y-y) < isSameDist);
   }
}