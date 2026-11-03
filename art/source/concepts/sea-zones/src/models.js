// docs/29 zones: water/fog/sky palette plus a brighter "key" for buoys, map and banner (shape carries zone too, not colour alone)
const ZONES=[
 {n:1,name:'Shallows',key:'#18D8CF',keyD:'#0A8F9B',glow:'#4FFFEF',water:'#25CBD8',deep:'#0FA3B8',foam:'#F4FFFC',fog:'#CFF4F8',skyTop:'#4DB4F4',skyHz:'#D8F6FF',clouds:'puffy',cloud:'#FFFFFF',fogD:1800,rough:.8,gem:'Rare'},
 {n:2,name:'Kelp Banks',key:'#62D92F',keyD:'#2A8C1E',glow:'#9CFF6A',water:'#50CB55',deep:'#1F9443',foam:'#F0FCDD',fog:'#DFF0B0',skyTop:'#78C8A4',skyHz:'#F0F5BC',clouds:'puffy',cloud:'#F3FBE4',fogD:1400,rough:.9,gem:'Epic'},
 {n:3,name:'Coral Drift',key:'#C453FF',keyD:'#7A23C4',glow:'#F0B5FF',cur:'#9A1FFF',tm:'#FFE3FB',water:'#6C68F0',deep:'#4136C2',foam:'#F7EDFF',fog:'#E6C6EF',skyTop:'#8583F2',skyHz:'#FFDAD4',clouds:'pink',cloud:'#FFE9EE',fogD:1300,rough:1,gem:'Legendary'},
 {n:4,name:'Storm Reach',key:'#55A6F0',keyD:'#2A5C8E',glow:'#FFFFFF',cur:'#C4EEFF',tm:'#EEF8FF',water:'#4C7288',deep:'#28475C',foam:'#E5EFF4',fog:'#A7B6C0',skyTop:'#4A5968',skyHz:'#B4C1C8',clouds:'deck',cloud:'#5B6B7A',cloud2:'#6E7E8C',fogD:780,rough:1.45,gem:'Mythic'},
 {n:5,name:'Wreck Abyss',key:'#4A3DE0',keyD:'#241A8A',glow:'#7566FF',tm:'#C3BBFF',water:'#1E1B58',deep:'#0D0B2E',foam:'#7E78F2',fog:'#3C3496',skyTop:'#110E30',skyHz:'#5C50C4',clouds:'stars',cloud:'#8D88E8',fogD:900,rough:1.15,gem:'Mythic'}];
const RARITY={Rare:'#4FB8FF',Epic:'#B07CFF',Legendary:'#FFC83A',Mythic:'#FF5CB8'};
const INK='#14121C';

// grinning skull + crossed oars on a black disc, unit coords (-1..1). Kid-safe: oars, not swords.
function skullTex(x,y){const r=Math.hypot(x,y);if(r>1)return null;if(r>.9)return'#FFF1D6';
  const oar=(a)=>{const c=Math.cos(a),s=Math.sin(a),u=x*c+y*s,v=-x*s+y*c;return Math.abs(v)<.06&&Math.abs(u)<.82||(Math.abs(u-.68)<.17&&Math.abs(v)<.15)};
  let col='#17141F';if(y<-.05&&(oar(.82)||oar(Math.PI-.82)))col='#F2B72A';
  if(y>=-.05&&(oar(-.82+Math.PI)||oar(.82-Math.PI+Math.PI*2-Math.PI)))col='#F2B72A';
  const hx=x,hy=y-.1,head=Math.hypot(hx,hy*1.05)<.56,jaw=Math.abs(x)<.31&&y<-.28&&y>-.62;
  if(head||jaw){const eye=(ex)=>Math.hypot(x-ex,y-.14)<.16;if(eye(-.21)||eye(.21))return Math.hypot(x-(x<0?-.25:.17),y-.19)<.05?'#FFFFFF':'#17141F';
    if(Math.abs(y+.1)<.09&&Math.abs(x)<.08-(y+.19)*-.0&&Math.abs(x)<(y+.19)*.5+.02)return'#17141F';
    if(jaw&&y<-.36&&Math.abs(Math.sin(x*15.7))<.2)return'#17141F';if(jaw&&Math.abs(y+.36)<.018)return'#17141F';return'#FFF1D6'}
  return col}

function char(m,p,shirt,o={}){const[x,y,z]=p,skin='#FFD79A',s=o.s||1,pants=o.pants||'#2A2E44';const B=(a,b,c,d,e,f,cl)=>m.box(x+a*s,x+b*s,y+c*s,y+d*s,z+e*s,z+f*s,cl);
  B(-.45,.45,0,1.9,-.95,-.05,pants);B(-.45,.45,0,1.9,.05,.95,pants);B(-.5,.5,1.9,3.8,-.95,.95,shirt);
  B(-.42,.42,1.9,3.7,-1.75,-1,shirt);
  if(o.fist)B(-.42,.42,3.2,6.3,1,1.75,shirt),B(-.46,.46,5.8,6.6,.96,1.78,skin);else B(-.42,.42,1.9,3.7,1,1.75,shirt);
  B(-.7,.7,3.85,5.25,-.7,.7,skin);m.part();m.box(x+.72*s,x+.74*s,y+4.45*s,y+4.75*s,z-.35*s,z-.12*s,INK,{same:1});m.box(x+.72*s,x+.74*s,y+4.45*s,y+4.75*s,z+.12*s,z+.35*s,INK,{same:1});
  if(o.hat=='tricorn'){B(-1.1,1.1,5.2,5.6,-1.1,1.1,'#17141F');m.part();m.poly([[x-1.3*s,y+5.6*s,z],[x+1.3*s,y+5.6*s,z+1.7*s],[x+1.3*s,y+5.6*s,z-1.7*s]],'#17141F');m.cyl([x,y+5.6*s,z],.8*s,1*s,'#17141F',{n:8,same:1,r1:.6*s});m.cyl([x+1.02*s,y+5.95*s,z],.32*s,.05*s,'#FFF1D6',{n:8,axis:'x'})}
  else{B(-.76,.76,4.85,5.4,-.76,.76,o.hat||'#D8262C');}}

function pirateBoat(){const m=new Mesh(),W='#6B3C22',WD='#4A2815',DK='#2E190E',TAN='#D2A264',RED='#D8262C',CR='#FFF1D6',GOLD='#F2B72A',IRON='#454B59';
  const O=(a,b,h)=>[[a,-h],[b-h*1.6,-h],[b-h*.55,-h*.55],[b,0],[b-h*.55,h*.55],[b-h*1.6,h],[a,h]];
  m.extrude(O(-17,20,5.5),-1,2,DK);m.extrude(O(-18,22,6.4),2,4.5,W);m.extrude(O(-19,23.5,6.9),4.5,6,GOLD);m.extrude(O(-20,25,7.3),6,8.5,W);
  m.extrude(O(-20.6,26,7.7),8.5,9.5,RED,{top:TAN});
  // fore castle, stepped stern castle: the galleon outline is the pirate read at distance
  m.extrude(O(11,24.6,6.6),9.5,12.5,WD,{top:TAN});
  m.box(-20.6,-7,9.5,14,-7.5,7.5,WD,{top:TAN});m.box(-23,-13,14,19,-8,8,RED,{top:TAN});m.box(-23.4,-12.6,18.2,19,-8.4,8.4,GOLD,{top:TAN});
  m.studs(-11,-8,-5,5,14,3,TAN);m.studs(-21,-15,-6,6,19,3,TAN);m.studs(13,20,-3,3,12.5,3,TAN);m.studs(-5,9,-5,5,9.5,3.5,TAN);
  // crenel rails, castle-tooth silhouette
  for(let x=-22.5;x<=-13.2;x+=2.4)for(const z of[-7.9,7.9])m.box(x-.6,x+.6,19,20.8,z-.5,z+.5,WD);
  for(let z=-5.6;z<=5.7;z+=2.8)m.box(-23.3,-22.3,19,20.8,z-.6,z+.6,WD);
  for(let x=-6;x<=11;x+=3.4)for(const z of[-7.4,7.4])m.box(x-.5,x+.5,9.5,11.6,z-.4,z+.4,WD);
  for(const z of[-7.4,7.4])m.box(-7,11.6,11.4,12,z-.45,z+.45,DK);
  for(let z=-5;z<=5;z+=2.5)m.box(-11.7,-12.7,14,15.2,z-.45,z+.45,WD);
  // lit stern windows + portholes: warm points that still read in Wreck Abyss
  for(const z of[-5.1,0,5.1]){m.box(-23.08,-23,15.2,17.5,z-1.5,z+1.5,'#FFD15C',{emi:1});}
  for(const x of[-18,-14.5])for(const z of[-8.06,8.0])m.box(x-1,x+1,15.2,17.5,z,z+.06,'#FFD15C',{emi:1});
  for(const x of[-14,-7,0,7,14])for(const s of[-1,1]){m.cyl([x,7.25,s*7.32],1,s*.05,DK,{n:10,axis:'z'});m.cyl([x,7.25,s*7.37],.68,s*.05,'#FFD15C',{n:10,axis:'z',emi:1})}
  // stern lantern
  m.box(-24.2,-23.6,19,24,-.3,.3,DK);m.box(-25.2,-23,24,24.5,-1.1,1.1,DK);m.box(-24.9,-23.3,24.5,27,-.8,.8,'#FFD15C',{emi:1});m.cyl([-24.1,27,0],1.5,1.1,DK,{n:6,r1:.3});
  // shark-jaw ram: the part that knocks you, so it gets the face
  const rect=(x,y0,y1,z)=>[[x,y0,-z],[x,y0,z],[x,y1,z],[x,y1,-z]];
  m.loft(rect(21,5,8.6,4.8),rect(33.5,5.4,6.8,1.5),'#7A8794',{bot:'#7A8794'});
  m.loft(rect(21,1.6,3.8,4.6),rect(30.5,2.5,3.6,1.5),'#7A8794');
  m.loft(rect(21,3.8,5,4.2),rect(27,3.9,5.1,1.8),'#7E1518');
  const fang=(a,b,yb,tipY,z)=>{m.part();m.poly([[a,yb,z],[b,yb,z],[(a+b)/2,tipY,z]],'#FFFFFF');};
  for(let i=0;i<6;i++){const x=22.4+i*1.85,z=lerp(4.72,2.0,i/6)+.08;for(const s of[-1,1]){m.part();m.poly([[x,lerp(5.1,5.42,i/6),s*z],[x+1.6,lerp(5.1,5.42,i/6),s*(z-.3)],[x+.8,lerp(3.95,4.1,i/6),s*(z-.1)]],'#FFFFFF')}}
  for(let i=0;i<4;i++){const x=22.6+i*1.9,z=lerp(4.5,2.1,i/4)+.08;for(const s of[-1,1]){m.part();m.poly([[x,lerp(3.72,3.62,i/4),s*z],[x+1.6,lerp(3.72,3.62,i/4),s*(z-.3)],[x+.8,lerp(4.85,4.65,i/4),s*(z-.1)]],'#FFFFFF')}}
  m.part();for(let i=0;i<3;i++){m.poly([[33.55,5.4,-1.2+i*.85],[33.55,5.4,-.5+i*.85],[33.55,4.5,-.85+i*.85]],'#FFFFFF')}
  for(const s of[-1,1]){m.cyl([26,7.1,s*3.55],1.05,s*.1,'#FFFFFF',{n:12,axis:'z'});m.cyl([26.3,6.95,s*3.66],.56,s*.08,INK,{n:10,axis:'z'});m.beam([24.7,8.15,s*3.65],[27.2,7.5,s*3.3],.5,'#4A505C')}
  // masts, yards, rig
  const MX=1.5,BR=.61,Rb=p=>{const dx=p[0]-MX,dz=p[2],c=Math.cos(BR),s=Math.sin(BR);return[MX+dx*c-dz*s,p[1],dx*s+dz*c]};m.box(MX-.9,MX+.9,9.5,49,-.9,.9,WD);m.beam(Rb([MX,36.2,-14]),Rb([MX,36.2,14]),1.1,WD);m.beam(Rb([MX,15.3,-11.6]),Rb([MX,15.3,11.6]),1,WD);
  for(const s of[-1,1])for(const dx of[-3.5,3.5]){m.beam([MX,34,0],[MX+dx,10,s*7.5],.28,DK)}
  m.beam([24,12,0],[38,20,0],.95,WD);m.beam([38,20,0],[MX+.9,38,0],.22,DK);
  const X=(u,v)=>MX+2.3+4.8*Math.sin(Math.PI*v)*(1-Math.pow(2*u-1,2)*.65);
  m.sheet((u,v)=>{const hw=lerp(13.2,11.2,v);return Rb([X(u,v),lerp(35.6,15.7,v),(2*u-1)*hw])},20,16,(u,v)=>{
    const hw=lerp(13.2,11.2,v),z=(2*u-1)*hw,y=lerp(35.6,15.7,v),ex=z/8.2,ey=(y-25.8)/8.2,sk=skullTex(ex,ey);if(sk)return sk;
    const k=Math.floor(u*16),bite=[0,1,0,0,2,0,1,0,0,2,0,0,1,0,2,0][k]; if(v>1-bite*.075)return null;
    return Math.floor(u*7)%2?CR:RED});
  m.part();m.poly([[36.5,19.6,0],[22,27.5,0],[26,13.6,0]],CR);
  // crow's nest + masthead flag
  m.cyl([MX,37,0],2.4,3.4,DK,{r1:3.1,n:10});m.cyl([MX,39.8,0],3.2,.7,GOLD,{n:10});char(m,[MX,37.2,0],'#FFF1D6',{s:.72,hat:'#D8262C'});
  m.sheet((u,v)=>{const x=MX-.9-u*13,bob=Math.sin(u*7)*.9*u;return[x,lerp(49,41.6,v)+bob,u*5.2+Math.cos(u*6)*.5]},16,6,(u,v)=>{
    if(u>.72&&Math.abs(v-.5)<(u-.72)*1.5)return null;const sk=skullTex((u-.34)/.26*(13/7.4),(.5-v)/.45*1.02);return sk&&Math.hypot((u-.34)/.26*(13/7.4),(.5-v)/.45)<.88?sk:'#17141F'});
  // crew + deck dressing
  char(m,[-18,19,0],'#7E1518',{hat:'tricorn'});char(m,[17,12.5,2],'#FFFFFF',{fist:1,hat:'#D8262C',pants:'#22315C'});char(m,[-3,9.5,-3.6],'#D8262C',{hat:'#FFF1D6'});
  m.cyl([-11.3,16,0],1.5,.4,GOLD,{axis:'x',n:10});m.box(-11.4,-10.4,14,16.4,-.3,.3,DK);
  for(const q of[[6,3.4],[4,5.6]]){m.cyl([q[0],9.5,q[1]],1.25,2.9,'#8A5A32',{n:9});m.cyl([q[0],10.3,q[1]],1.33,.3,DK,{n:9});m.cyl([q[0],11.5,q[1]],1.33,.3,DK,{n:9})}
  return m}

function standinSki(){const m=new Mesh();const c='#F26A1B';m.loft([[-5,.1,-1.7],[-5,.1,1.7],[-5,1.8,1.9],[-5,1.8,-1.9]],[[4.8,.5,-.4],[4.8,.5,.4],[4.8,2.4,.3],[4.8,2.4,-.3]],'#FFFFFF');
  m.box(-4.8,1.5,1.8,2.5,-1.3,1.3,c);m.box(-3.6,-.6,2.5,3,-.9,.9,'#23303C');m.box(1.3,1.9,2.5,3.5,-1.5,1.5,'#23303C');
  char(m,[-1.6,2.8,0],'#F26A1B',{s:.95,hat:'#FFFFFF',pants:'#23303C'});return m}
function swimmer(){const m=new Mesh();m.cyl([0,.02,0],8.6,.16,'#FFFFFF',{n:28});m.cyl([0,.07,0],7.3,.18,'#FF6A10',{n:28,emi:1});m.cyl([0,.13,0],5.4,.22,'#BFEFF5',{n:28});m.box(-1.1,1.1,-.2,1.9,-1.3,1.3,'#FF6A10',{emi:1});m.box(-1,1,1.9,2.3,-1,1,'#FFFFFF',{emi:1});m.box(-.8,.8,2.3,3.9,-.8,.8,'#FFD79A');m.box(-.4,.4,1,4.6,1.1,1.8,'#F26A1B');return m}

// tall Lego buoy. Zone reads three ways: colour, topmark shape, count of white bands.
function buoy(zi,o={}){const z=ZONES[zi],m=new Mesh(),K=z.key,D=z.keyD,WH='#FFFFFF',PH=Math.PI/8;
  const C=(y,r,h,c,x={})=>m.cyl([0,y,0],r,h,c,{n:8,ph:PH,...x});
  C(-2,7,3.5,D);C(1.5,7.6,3,K);C(4.5,7.6,.8,WH);C(5.3,5.6,1,D);
  m.part();for(let i=0;i<8;i++){const a=i/8*6.283;m.cyl([Math.cos(a)*6.6,5.3,Math.sin(a)*6.6],.62,.38,WH,{n:8,same:1})}
  let y=6.3;const courses=11;for(let i=0;i<courses;i++){const r=lerp(5,3.5,i/(courses-1)),band=i%2==1&&(i+1)/2<=z.n;C(y,r,2,band?WH:K);y+=2}
  C(y,5,.9,D);y+=.9;const ly=y,gl=o.lampOff?K:z.glow;C(y,3.1,5,gl,{emi:1});
  for(let i=0;i<4;i++){const a=PH*2*i+PH*2+.0,x=Math.cos(a)*3.5,zz=Math.sin(a)*3.5;m.box(x-.35,x+.35,y,y+5,zz-.35,zz+.35,D)}y+=5;C(y,4.4,1.2,K,{r1:2.8});y+=1.2;
  const W2=z.tm||z.key,tmo=z.tm?{emi:1}:{},cross=(fn)=>fn(1);
  const P=(pts0,s,c)=>{const pts=pts0.map(p=>[p[0]*1.45,p[1]*1.45]),yy=y;const f=p=>s?[0+p[2]||0,yy+p[1],p[0]]:[p[0],yy+p[1],p[2]||0];
    const A=pts.map(p=>{const q=f([p[0],p[1],-.55]);return s?[-.55,q[1],p[0]]:[p[0],q[1],-.55]}),B=pts.map(p=>s?[.55,yy+p[1],p[0]]:[p[0],yy+p[1],.55]);m.loft(A,B,c,tmo)};
  if(z.n==1)cross(s=>{const arc=[];for(let k=0;k<=8;k++){const a=.35+k/8*2.44;arc.push([Math.cos(a)*5,.4+Math.sin(a)*5])}P([[-.9,0],[.9,0],...arc],s,W2);
    for(let k=0;k<7;k++){const a=.38+k/6*2.38,cx=Math.cos(a)*5,cy=.4+Math.sin(a)*5,oc=[];for(let q=0;q<8;q++)oc.push([cx+Math.cos(q/8*6.283)*.72,cy+Math.sin(q/8*6.283)*.72]);P(oc,s,W2)}
    for(let k=0;k<5;k++){const a=.62+k/4*1.9;for(const sd of[-.63,.63])m.beam([sd,y+1.6,Math.cos(a)*1.2],[sd,y+(.4+Math.sin(a)*4.8)*1.45,Math.cos(a)*4.8*1.45],.42,D)}});
  else if(z.n==2)cross(s=>{for(const q of[[[-.6,0],[.6,0],[1,3],[-.2,3]],[[-.2,3],[1,3],[.3,6],[-.8,6]],[[-.8,6],[.3,6],[.9,8.8],[.3,8.8]],
    [[.6,1],[3.8,2.2],[4,3.5],[.7,2.8]],[[-.2,2.8],[-3.5,4],[-3.7,5.4],[-.3,4.6]],[[.5,4.6],[3.2,6],[3.2,7.2],[.3,6.4]],[[-.6,6],[-2.7,7.4],[-2.5,8.5],[-.2,7.6]]])P(q,s,W2)});
  else if(z.n==3)cross(s=>{P([[-.7,0],[.7,0],[.7,7.8],[-.7,7.8]],s,W2);P([[.5,1.8],[3.3,3.8],[3.3,5.2],[.5,3.2]],s,W2);P([[2.2,3.2],[3.6,3.2],[3.6,6.4],[2.2,6.4]],s,W2);P([[-.5,3.2],[-3.1,5],[-3.1,6.2],[-.5,4.6]],s,W2);P([[-3.3,4.8],[-2,4.8],[-2,7],[-3.3,7]],s,W2)});
  else if(z.n==4)cross(s=>{P([[1,8.4],[3,8.4],[1.2,4.9],[-2,3.6]],s,W2);P([[-.4,4.6],[3,5],[-1.6,-.6]],s,W2)});
  else cross(s=>{P([[-.55,1.2],[.55,1.2],[.55,7],[-.55,7]],s,W2);P([[-2,5.2],[2,5.2],[2,6.2],[-2,6.2]],s,W2);P([[-.6,0],[.6,0],[3.4,2.2],[2.3,2.6]],s,W2);P([[-.6,0],[.6,0],[-2.3,2.6],[-3.4,2.2]],s,W2);P([[2.3,1.6],[3.4,1.6],[3.4,3.8],[2.3,3.8]],s,W2);P([[-3.4,1.6],[-2.3,1.6],[-2.3,3.8],[-3.4,3.8]],s,W2);m.part();
    m.cyl([-.55,y+11.3,0],1.6,1.1,W2,{n:10,axis:'x',...tmo})});
  return m}

// zone landmarks for the from-a-boat board (concept stand-ins)
function landmark(zi){const m=new Mesh();
  if(zi==0){m.box(-160,160,-3,5,-260,260,'#3DB54A',{top:'#45C553'});m.part();for(let x=-150;x<=150;x+=26)for(let z=-250;z<=250;z+=26)m.cyl([x,5,z],4,1.6,'#4FD45E',{n:6,same:1});
    m.box(-60,-10,5,40,-60,-10,'#F4F1E6',{top:'#D8262C'});m.box(-40,10,5,26,40,110,'#3C8CE7',{top:'#FFD24A'});m.cyl([60,5,-110],8,70,'#FFFFFF',{n:8,r1:6});m.cyl([60,50,-110],9,12,'#D8262C',{n:8});m.box(-50,0,5,20,-210,-150,'#FFCB3D',{top:'#E85D2A'})}
  if(zi==1){for(const[x,z,h]of[[0,-6,46],[46,-44,64],[30,38,38],[100,12,72],[-30,-74,50],[150,-74,58],[120,86,44]])for(const dz of[-4,4]){m.part();const seg=9,G='#128F4E',L='#3BD46A',at=k=>[x+Math.sin(k*.8+dz)*2,k/seg*h,z+dz+Math.sin(k*.72+dz)*3.4];
      for(let k=0;k<seg;k++)m.beam(at(k),at(k+1),2.2,G,{same:1});
      for(let k=2;k<=seg;k++){const p=at(k),s=k%2?1:-1,ll=lerp(13,7,k/seg);m.poly([p,[p[0],p[1]+3.2,p[2]+s*ll*.5],[p[0],p[1]+1.6,p[2]+s*ll],[p[0],p[1]-2.2,p[2]+s*ll*.5]],L);m.cyl([p[0],p[1]-1,p[2]+s*1.2],1.5,2,'#F2D23C',{n:6,same:1})}}
    m.box(280,420,-2,26,-170,10,'#6E9A60',{top:'#82C25E'});m.box(310,390,26,42,-120,-30,'#5D8A58',{top:'#94D06A'})}
  if(zi==2){const T=(x,z,h,c)=>{m.part();m.cyl([x,0,z],5,h,c,{n:7,r1:3.4,same:1});for(const a of[.7,2.8,4.6]){const bx=x+Math.cos(a)*9,bz=z+Math.sin(a)*9;m.beam([x,h*.55,z],[bx,h*.92,bz],3,c,{same:1});m.cyl([bx,h*.9,bz],2.3,h*.3,c,{n:6,same:1,r1:1.6})}};
    T(0,0,34,'#FF6E9E');T(50,-52,48,'#FFA24A');T(60,58,28,'#FFD24A');T(130,-10,62,'#FF4F86');T(190,80,44,'#FF8FB0');T(-30,-110,38,'#FFC15A');
    T(-70,70,30,'#FF7FB0');T(95,-120,54,'#FF6E9E')}
  if(zi==3){for(const[x,z,h,r]of[[0,-30,90,26],[80,70,140,36],[150,-80,120,30],[-40,110,70,20],[240,20,190,48],[300,-160,120,34]]){m.part();m.cyl([x,-2,z],r,h*.6,'#3F4D58',{n:6,r1:r*.72,same:1});m.cyl([x+r*.1,h*.6-2,z],r*.72,h*.4,'#4B5A65',{n:5,r1:r*.25,same:1})}}
  if(zi==4){m.part();const W='#1F183E',W2='#171232';m.loft([[-70,-4,-20],[-70,-4,20],[-70,36,26],[-70,36,-26]],[[90,-14,-4],[90,-14,4],[100,34,6],[100,34,-6]],W);
    m.box(-66,6,36,52,-24,24,W2);m.box(-40,-38,50,132,-2,2,W2);m.beam([30,30,0],[66,108,18],4.5,W2);m.box(-41,-37,104,108,-30,30,W2);m.sheet((u,v)=>[-39+Math.sin(v*3)*4,104-v*50,(2*u-1)*26],8,6,(u,v)=>(u*7%1)<.5&&v>.8?null:'#2A2150');
    m.box(-60,-54,58,66,-3,3,'#FFD15C',{emi:1});m.box(-71,-70,14,24,-14,-6,'#FFD15C',{emi:1});m.box(-71,-70,14,24,6,14,'#FFD15C',{emi:1});m.box(-70,100,36,37.5,-1,1,'#A69CFF',{emi:1});m.box(-42,-40.6,50,132,-2.4,2.4,'#A69CFF',{emi:1});m.box(-41,-37,108,109.2,-30,30,'#A69CFF',{emi:1});m.beam([30,31,1.6],[66,109,19.6],1.2,'#A69CFF',{emi:1});m.cyl([150,-2,-60],22,40,'#1B1638',{n:5,r1:6});m.cyl([-120,-2,90],26,56,'#1B1638',{n:5,r1:5})}
  return m}
