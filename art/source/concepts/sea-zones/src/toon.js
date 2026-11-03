// Tiny z-buffer toon renderer + sea painter: true 3D views of one model, so front/side/3-4/game camera all agree.
window.onerror=(m,s,l)=>{document.body.insertAdjacentHTML('afterbegin',`<pre style="color:#f33;font-size:22px;position:fixed;z-index:9">${m} @${l}</pre>`)};
const RGB=h=>Array.isArray(h)?h:[parseInt(h.slice(1,3),16),parseInt(h.slice(3,5),16),parseInt(h.slice(5,7),16)];
const mixc=(a,b,t)=>[a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t];
const sub=(a,b)=>[a[0]-b[0],a[1]-b[1],a[2]-b[2]],dot=(a,b)=>a[0]*b[0]+a[1]*b[1]+a[2]*b[2];
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const norm=a=>{const l=Math.hypot(a[0],a[1],a[2])||1;return[a[0]/l,a[1]/l,a[2]/l]};
const lerp=(a,b,t)=>a+(b-a)*t;

class Mesh{
  constructor(){this.t=[];this.cur=0;this.n=0}
  part(){return this.cur=++this.n}
  tri(a,b,c,col,o={}){const n=cross(sub(b,a),sub(c,a));if(!dot(n,n))return;
    this.t.push({a,b,c,col:RGB(col),n:norm(n),id:this.cur,emi:o.emi,tex:o.tex,ua:o.ua,ub:o.ub,uc:o.uc})}
  poly(p,col,o){for(let i=1;i<p.length-1;i++)this.tri(p[0],p[i],p[i+1],col,o)}
  // ring to ring; both rings same length
  loft(A,B,col,o={}){if(!o.same)this.part();const n=A.length;
    for(let i=0;i<n;i++){const j=(i+1)%n;this.poly([A[i],A[j],B[j],B[i]],col,o)}
    if(!o.open){this.poly(A,o.bot||col,o);this.poly(B,o.top||col,o)}}
  extrude(out,y0,y1,col,o={}){this.loft(out.map(p=>[p[0],y0,p[1]]),out.map(p=>[p[0],y1,p[1]]),col,o)}
  box(x0,x1,y0,y1,z0,z1,col,o={}){this.extrude([[x0,z0],[x1,z0],[x1,z1],[x0,z1]],y0,y1,col,o)}
  // axis-aligned cylinder from base c along +axis
  cyl(c,r,h,col,o={}){const n=o.n||10,ax=o.axis||'y',A=[],B=[],r1=o.r1??r,ph=o.ph||0;
    for(let i=0;i<n;i++){const s=ph+i/n*Math.PI*2,u=Math.cos(s),v=Math.sin(s);
      const P=(rr,d)=>ax=='y'?[c[0]+u*rr,c[1]+d,c[2]+v*rr]:ax=='x'?[c[0]+d,c[1]+u*rr,c[2]+v*rr]:[c[0]+u*rr,c[1]+v*rr,c[2]+d];
      A.push(P(r,0));B.push(P(r1,h))}
    this.loft(A,B,col,o)}
  beam(p,q,t,col,o={}){const d=norm(sub(q,p));const a=norm(cross(d,Math.abs(d[1])>.9?[1,0,0]:[0,1,0])),b=cross(d,a);
    const R=c=>[[1,1],[-1,1],[-1,-1],[1,-1]].map(s=>[c[0]+(a[0]*s[0]+b[0]*s[1])*t/2,c[1]+(a[1]*s[0]+b[1]*s[1])*t/2,c[2]+(a[2]*s[0]+b[2]*s[1])*t/2]);
    this.loft(R(p),R(q),col,o)}
  // curved sheet with per-pixel paint; tex returning null punches a hole
  sheet(fn,nu,nv,tex){this.part();for(let i=0;i<nu;i++)for(let j=0;j<nv;j++){const u0=i/nu,u1=(i+1)/nu,v0=j/nv,v1=(j+1)/nv;
    const a=fn(u0,v0),b=fn(u1,v0),c=fn(u1,v1),d=fn(u0,v1);
    this.tri(a,b,c,'#ffffff',{tex,ua:[u0,v0],ub:[u1,v0],uc:[u1,v1]});this.tri(a,c,d,'#ffffff',{tex,ua:[u0,v0],ub:[u1,v1],uc:[u0,v1]})}}
  studs(x0,x1,z0,z1,y,step,col){this.part();for(let x=x0;x<=x1+.01;x+=step)for(let z=z0;z<=z1+.01;z+=step)this.cyl([x,y,z],.62,.38,col,{n:8,same:1})}
}
// orbit camera: ppu = orthographic pixels-per-stud; otherwise perspective with F (pixels)
function orbit(target,az,el,dist,o={}){const d=[Math.cos(el)*Math.cos(az),Math.sin(el),Math.cos(el)*Math.sin(az)];
  return camFrom([target[0]+d[0]*dist,target[1]+d[1]*dist,target[2]+d[2]*dist],[-d[0],-d[1],-d[2]],o)}
function camFrom(pos,f,o){const r=norm(cross(f,[0,1,0]));return{pos,f,r,u:cross(r,f),ppu:o.ppu,F:o.F,cx:o.cx,cy:o.cy}}
// game camera over the sea: horizon sits at hz px, yaw turns about Y. +X is ahead at yaw 0.
function seaCam(W,H,hz,F,camH,yaw=0){const p=Math.atan((H/2-hz)/F);
  return camFrom([0,camH,0],[Math.cos(p)*Math.cos(yaw),-Math.sin(p),Math.cos(p)*Math.sin(yaw)],{F})}

const LIGHT=norm([.45,.8,.42]);
function render(items,cam,W,H,o={}){
  const ss=o.ss||3,w=W*ss,h=H*ss,N=w*h,zb=new Float32Array(N).fill(-Infinity),idb=new Int32Array(N);
  const col=new Uint8ClampedArray(N*3),nb=new Int8Array(N*3),bands=o.bands||7,ortho=!!cam.ppu;
  const cx=(cam.cx??.5)*w,cy=(cam.cy??.5)*h,K=ortho?cam.ppu*ss:cam.F*ss;let idOff=0;
  const pj=v=>{const d=sub(v,cam.pos),zc=dot(d,cam.f);if(!ortho&&zc<.2)return null;const s=ortho?K:K/zc;
    return[cx+dot(d,cam.r)*s,cy-dot(d,cam.u)*s,ortho?1e4-zc:1/zc,ortho?1:1/zc]};
  for(const it of(Array.isArray(items)?items:[items])){const m=it.mesh||it,P=it.pos||[0,0,0],yw=it.yaw||0,S=it.scale||1,cs=Math.cos(yw),sn=Math.sin(yw);
    const X=v=>[P[0]+(v[0]*cs-v[2]*sn)*S,P[1]+v[1]*S,P[2]+(v[0]*sn+v[2]*cs)*S],XN=n=>[n[0]*cs-n[2]*sn,n[1],n[0]*sn+n[2]*cs];
    for(const t of m.t){const A=X(t.a),B=X(t.b),C=X(t.c),a=pj(A),b=pj(B),c=pj(C);if(!a||!b||!c)continue;
      const area=(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]);if(Math.abs(area)<1e-4)continue;
      let n=XN(t.n);const vd=ortho?[-cam.f[0],-cam.f[1],-cam.f[2]]:sub(cam.pos,A);if(dot(n,vd)<0)n=[-n[0],-n[1],-n[2]];
      let s=1;if(!t.emi){s=.6+.14*n[1]+.48*Math.max(0,dot(n,LIGHT));s=Math.round(s*bands)/bands}
      const c0=[t.col[0]*s,t.col[1]*s,t.col[2]*s],id=t.id+idOff;
      const x0=Math.max(0,Math.floor(Math.min(a[0],b[0],c[0]))),x1=Math.min(w-1,Math.ceil(Math.max(a[0],b[0],c[0])));
      const y0=Math.max(0,Math.floor(Math.min(a[1],b[1],c[1]))),y1=Math.min(h-1,Math.ceil(Math.max(a[1],b[1],c[1])));
      for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++){const px=x+.5,py=y+.5;
        const w0=((b[0]-px)*(c[1]-py)-(b[1]-py)*(c[0]-px))/area,w1=((c[0]-px)*(a[1]-py)-(c[1]-py)*(a[0]-px))/area,w2=1-w0-w1;
        if(w0<0||w1<0||w2<0)continue;const z=w0*a[2]+w1*b[2]+w2*c[2],i=y*w+x;if(z<=zb[i])continue;
        let r=c0[0],g=c0[1],bl=c0[2];
        if(t.tex){const iw=w0*a[3]+w1*b[3]+w2*c[3],q0=w0*a[3]/iw,q1=w1*b[3]/iw,q2=w2*c[3]/iw;
          const k=t.tex(q0*t.ua[0]+q1*t.ub[0]+q2*t.uc[0],q0*t.ua[1]+q1*t.ub[1]+q2*t.uc[1]);if(!k)continue;const kc=RGB(k);r=kc[0]*s;g=kc[1]*s;bl=kc[2]*s}
        zb[i]=z;idb[i]=id;col[i*3]=r;col[i*3+1]=g;col[i*3+2]=bl;nb[i*3]=n[0]*127;nb[i*3+1]=n[1]*127;nb[i*3+2]=n[2]*127}}
    idOff+=m.n+1}
  const line=o.line??0,out=new Uint8ClampedArray(N*4),L=RGB(o.lineCol||'#14121C');
  const dirs=[[1,0],[-1,0],[0,1],[0,-1],[.7,.7],[-.7,.7],[.7,-.7],[-.7,-.7]];
  const rIn=line*ss,rOut=(o.lineOuter??line*1.5)*ss,fog=o.fog&&{c:RGB(o.fog.col),s:o.fog.start,e:o.fog.end};
  for(let y=0;y<h;y++)for(let x=0;x<w;x++){const i=y*w+x,pid=idb[i];let edge=0;
    if(line>0){const R=pid?rIn:rOut;
      for(const k of[1,.5])for(const d of dirs){const nx=Math.round(x+d[0]*R*k),ny=Math.round(y+d[1]*R*k);if(nx<0||ny<0||nx>=w||ny>=h)continue;
        const q=ny*w+nx,qid=idb[q];if(!qid)continue;
        if(!pid||(qid!=pid&&(zb[q]>zb[i]||(zb[q]==zb[i]&&qid>pid))))edge=1;
        else if(qid==pid&&k==.5&&edge<.6&&nb[q*3]*nb[i*3]+nb[q*3+1]*nb[i*3+1]+nb[q*3+2]*nb[i*3+2]<9000)edge=.6}}
    if(!pid&&!edge)continue;
    let r=col[i*3],g=col[i*3+1],b=col[i*3+2];
    if(fog&&pid){const dist=ortho?0:1/zb[i],t=Math.min(1,Math.max(0,(dist-fog.s)/(fog.e-fog.s)));r=lerp(r,fog.c[0],t);g=lerp(g,fog.c[1],t);b=lerp(b,fog.c[2],t)}
    if(edge){r=lerp(r,L[0],edge);g=lerp(g,L[1],edge);b=lerp(b,L[2],edge)}
    out[i*4]=r;out[i*4+1]=g;out[i*4+2]=b;out[i*4+3]=255}
  const cv=document.createElement('canvas');cv.width=W;cv.height=H;const cx2=cv.getContext('2d'),im=cx2.createImageData(W,H),s2=ss*ss;
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){let r=0,g=0,b=0,a=0;
    for(let j=0;j<ss;j++)for(let k=0;k<ss;k++){const q=((y*ss+j)*w+x*ss+k)*4,al=out[q+3];r+=out[q]*al;g+=out[q+1]*al;b+=out[q+2]*al;a+=al}
    const q=(y*W+x)*4;if(a){im.data[q]=r/a;im.data[q+1]=g/a;im.data[q+2]=b/a;im.data[q+3]=a/s2}}
  cx2.putImageData(im,0,0);return cv}
function silhouette(cv,c){const o=document.createElement('canvas');o.width=cv.width;o.height=cv.height;const x=o.getContext('2d');x.drawImage(cv,0,0);x.globalCompositeOperation='source-in';x.fillStyle=c;x.fillRect(0,0,o.width,o.height);return o}
function project(cam,W,H,v){const d=sub(v,cam.pos),zc=dot(d,cam.f);if(cam.ppu)return[W*(cam.cx??.5)+dot(d,cam.r)*cam.ppu,H*(cam.cy??.5)-dot(d,cam.u)*cam.ppu];return[W/2+dot(d,cam.r)*cam.F/zc,H/2-dot(d,cam.u)*cam.F/zc,zc]}

// Toon sea + sky, using the same camera maths as the renderer so objects sit on it.
function paintSea(ctx,W,H,hz,F,camH,pal,o={}){const im=ctx.createImageData(W,H),d=im.data,seed=o.seed||0;
  const w=RGB(pal.water),t=RGB(pal.deep),hi=mixc(w,[255,255,255],.2),fo=RGB(pal.foam),fg=RGB(pal.fog),st=RGB(pal.skyTop),sh=RGB(pal.skyHz),rough=pal.rough||1;
  for(let y=0;y<H;y++){const a=(hz-y)/F;for(let x=0;x<W;x++){const q=(y*W+x)*4;let c;
    if(y<hz){const k=Math.pow(Math.min(1,(hz-y)/(hz*1.05)),.75);c=mixc(sh,st,k);const f=Math.exp(-(hz-y)/(H*.035));c=mixc(c,fg,f*.85)}
    else{const dist=camH/Math.max(.0015,(y+.5-hz)/F),lat=(x-W/2)/F*dist,wv=dist,far=Math.min(1,dist/900);
      let v=.5+.22*Math.sin(wv*.055+lat*.017+seed)+.16*Math.sin(wv*.13-lat*.05+1.3*seed)*(1-far)+.1*Math.sin(wv*.27+lat*.11)*(1-far)*(1-far);
      v=.5+(v-.5)*rough;
      c=v<.36?mixc(t,w,.25):v<.6?w:v<.625?mixc(hi,[255,255,255],.35):hi;
      const foam=Math.sin(wv*.09+lat*.024+seed)*.5+.5+.5*(Math.sin(lat*.5+wv*.04)*.5);
      const crest=.7+(1-rough*.5)*.1;if(v>crest&&v<crest+.035&&foam>.62&&dist>70&&dist<700)c=fo;
      const f=1-Math.exp(-dist/(pal.fogD||1400));c=mixc(c,fg,f*.92)}
    d[q]=c[0];d[q+1]=c[1];d[q+2]=c[2];d[q+3]=255}}
  ctx.putImageData(im,0,0);clouds(ctx,W,H,hz,pal,seed)}
function rng(s){return()=>(s=(s*16807)%2147483647)/2147483647}
function clouds(c,W,H,hz,pal,seed){const R=rng(1234+seed*97|0),k=pal.clouds,col=pal.cloud||'#fff';c.save();c.beginPath();c.rect(0,0,W,hz-2);c.clip();
  if(k=='deck'){for(let i=0;i<22;i++){const y=R()*hz*.75;c.fillStyle=i%2?pal.cloud:pal.cloud2;c.beginPath();c.ellipse(R()*W,y,W*(.25+R()*.3),8+R()*H*.035,0,0,7);c.fill()}}
  else if(k=='puffy'||k=='pink'){for(let i=0;i<5;i++){const x=R()*W,y=hz*(.18+R()*.62),s=W*(.09+R()*.09);c.fillStyle=col;for(let j=0;j<6;j++){c.beginPath();c.arc(x+(j-2.5)*s*.62,y-Math.sin(j/5*3.14)*s*.55,s*(.45+.25*Math.sin(j/5*3.14)),0,7);c.fill()}c.fillRect(x-s*1.9,y-1,s*3.5,s*.34)}}
  else if(k=='stars'){c.fillStyle=col;for(let i=0;i<60;i++){const s=R()<.15?2:1;c.fillRect(R()*W,R()*hz*.8,s,s)}}
  c.restore()}
// glow curtain: a soft tinted sheet standing on the water from world A to B; plain alpha because additive washes out to white on bright skies
function curtain(c,cam,W,H,A,B,hgt,z,alpha=.62,fade=[1,1],seed=0){const C=RGB(z.cur||z.key),G=RGB(z.glow),n=240;c.save();
  for(let i=0;i<n;i++){const t=i/n,t1=(i+1)/n,P=q=>[lerp(A[0],B[0],q),0,lerp(A[1],B[1],q)];
    const p0=project(cam,W,H,P(t)),p1=project(cam,W,H,P(t1)),top=project(cam,W,H,[P(t)[0],hgt,P(t)[2]]);
    if(p0[2]<1)continue;const x0=Math.min(p0[0],p1[0]),x1=Math.max(p0[0],p1[0]);if(x1<0||x0>W)continue;
    const streak=.62+.38*Math.sin(t*90+seed)*Math.sin(t*37.3+seed*2),a=alpha*lerp(fade[0],fade[1],t),ww=Math.max(.6,x1-x0+.5);
    const g=c.createLinearGradient(0,p0[1],0,top[1]);g.addColorStop(0,`rgba(${G},${a})`);g.addColorStop(.1,`rgba(${C},${a})`);g.addColorStop(.5,`rgba(${C},${Math.min(1,a*.72)*streak})`);g.addColorStop(1,`rgba(${C},0)`);
    c.fillStyle=g;c.fillRect(x0,top[1],ww,p0[1]-top[1]);
    const r=Math.max(2,(p0[1]-top[1])*.07),g2=c.createLinearGradient(0,p0[1],0,p0[1]+r);g2.addColorStop(0,`rgba(${G},${a*.75})`);g2.addColorStop(1,`rgba(${C},0)`);c.fillStyle=g2;c.fillRect(x0,p0[1],ww,r);
    const ft=Math.max(1.5,(p0[1]-top[1])*.022),W2=mixc(G,[255,255,255],.55).map(Math.round);c.fillStyle=`rgba(${W2},${Math.min(1,a*1.15)})`;c.fillRect(x0,p0[1]-ft,ww,ft*1.6)}
  c.restore()}
function canvasIn(el,W,H,css){const c=document.createElement('canvas');c.width=W;c.height=H;c.style.cssText=`display:block;width:${css?css[0]:W}px;height:${css?css[1]:H}px`;el.appendChild(c);return c}
