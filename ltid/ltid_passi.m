function ltid_passi(fnm,st)
% function ltid_passi(fnm,st)
%
% wrapper for converting frequency domain data to a passive LTI model L
% reads/writes data from/to file ffnm=[fnm '_psi.mat'], begins at step st
% default fnm='ltid', st=1
%
% st=1: read n-by-1 "freq" (CT frequency in Hz) and 
%       k-by-k-by-N "Z_sym" from ffnm 
%       plot v vs. 2*pi*f (frequency in rad/sec) 
%       prompt for the Tustin transform frequency f0 (rad/sec)
% st=2: produce the DT frequency w and plot real(v) vs. w 
%       prompt for non-zero imaginary axis poles t outside the range of w
% st=3: prompt for order and relative accuracy find a rational fit
%       */aa to imaginary part of the frequency response
% st=4: using the denominator aa from st 3, fit the data (produce G,h)
% st=5: apply model reduction and produce the final result L

if nargin<1, fnm='ltid'; end
if nargin<2, st=1; end
ffnm=[fnm '_psi.mat'];
if exist(ffnm,'file')~=2, error(['file ' ffnm ' not found']); end
load(ffnm)
if ~exist('freq','var'), error(['variable freq not found in ' ffnm]); end
if ~exist('Z_sym','var'), error(['variable Z_sym not found in ' ffnm]); end
szv=size(Z_sym);
if (size(szv,2)~=3)||(szv(1)~=szv(2)), error('Z_sym is not k-by-k-by-n'); end
k=szv(1);
n=szv(3);
N=nchoosek(k+1,2);
ix=mss_v2s(1:N,0);
xi=mss_s2v(reshape(1:k^2,k,k),0);
I=eye(k);
jj=m:-2:1; jj=2*jj(end:-1:1)-1;     % number of elements per level
ss=cumsum(jj);                  % "last element on the level" numbers
njj=length(jj);                     % number of levels

if ~isequal(size(freq),[n 1]), error('incompatible Z_sym and freq'); end
vw=reshape(permute(Z_sym,[3 1 2]),n,k^2);
v=vw(:,xi);

if st<2,                              % Tustin transform 
    w=(2*pi)*freq;
    close(gcf);
    subplot(2,1,1);plot(w,real(vw));grid
    subplot(2,1,2);plot(w,imag(vw));grid
    f00=5*max(freq);
    s00=sprintf('%e',f00);
    f0=input([' Choose conversion frequency (default ' s00 '): ']);
    if isempty(f0), f0=f00; end
    save(ffnm,'freq','Z_sym','f0');
end
if ~exist('f0','var'), error(['variable f0 not found in ' ffnm]); end
w=(2*pi/f0)*freq;
w=angle((1+1i*w)./(1-1i*w));
wmin=min(w);
wmax=max(w);

if st<3,
    close(gcf);
    subplot(2,1,1);plot(w,real(vw));grid
    subplot(2,1,2);plot(w,imag(vw));grid
    t=input([' Choose pole frequencies from (0,' num2str(wmin) ...
        ') or (' num2str(wmax) ',pi): ']);
end
if ~exist('t','var'), error(['variable t not found in ' ffnm]); end
t=sort([0;real(t(:))]);                   % order
t=t((t>=0)&(t<pi)&((t<wmin)|(t>wmax)));   % enforce bounds
t=t(t<[t(2:end);4]);                      % remove repeated poles
nt=length(t);
zw=repmat(exp(1i*w),1,nt);
cst=repmat(cos(t)',n,1);
r=prod(imag((zw.^2-2*zw.*cst+1)./(zw.^2-1)),2);
%close(gcf);plot(w,r);grid

if st<4,
    m=input(' Choose denominator degree (default 10): ');
    if isempty(m), m=10; end
    h=input(' Choose relative accuracy (default 0.1): ');
    if isempty(h), h=0.1; end
    aa=zeros(m+1,njj);   % to keep denominators
    for i=1:njj,         % fit each centered square separately
        fprintf(' fitting Im of square %2d ...',i);
        u=imag(v(:,ss(i)-jj(i)+1:ss(i)));
        [aaa,bbb]=ltid_vw2ab(u.*repmat(r,1,jj(i)),w,m,-2,h,abs(r));
        aa(:,i)=aaa;
        uh=ltid_wabc2v(w,aaa,bbb)./repmat(r,1,jj(i));
        e=u-uh;
        er=sqrt(max(sum(abs(e).^2,2)));
        fprintf(' done:  matching error = %f\n',er);
    end
    save(ffnm,'freq','Z_sym','f0','t','aa') 
end
return

if ~exist('aa','var'), error(['variable aa not found in ' ffnm]); end

if st<5,   
    [G,h]=ltid_vwat2Gh(vw,w,aa,t,2);
    G=0.5*(G+G.');
    save(ffnm,'freq','Z_sym','f0','t','aa','G','h')    
    H=ltid_th2H(t,h);
    fprintf(' analytical passivity check: %f<1\n',norm((I-G)/(I+G),Inf))
    vw1=reshape(permute(freqresp(G+H,w),[3 1 2]),n,k^2);
    e=vw-vw1;
    maxe=sqrt(max(sum(abs(e(:,ix)).^2,2)));
    fprintf(' matching error: %f\n',maxe)
    close(gcf);plot(w,sqrt(sum(abs(e(:,ix)).^2,2)),'.');grid; pause
end
if ~exist('G','var'), error(['variable G not found in ' ffnm]); end
if ~exist('h','var'), error(['variable h not found in ' ffnm]); end
ntt=input(' Choose no. of testing samples (default 3000): ');
if isempty(ntt), ntt=3000; end
tt=sort([w;linspace(0,pi,ntt)']);   % testing frequencies
ntt=length(tt);
r=input([' Select H-tolerance (default 1): ']);
if isempty(r), r=1; end
H=ltid_th2H(t,h,w,r);
fprintf(' order(H)=%d\n',order(H))
hG=hsvd(G);
d0=length(hG);
close(gcf);semilogy(hG,'.');grid
d=input([' Choose reduced model order (default ' num2str(d0) '): ']);
if isempty(d), d=d0; end
d=max(1,min(d0,round(d)));
Gr=reduce(G,d);
fprintf(' balanced truncation error: %f\n',norm(G-Gr,Inf))
fprintf(' passivity check (DT): %f<1\n',norm((I-Gr)/(I+Gr),Inf))
r=input([' Choose leakage (default 0.9995): ']);
if isempty(r), r=0.9995; end
[a,b,c,d]=ssdata(H);
L=Gr+ss(r*a,r*b,r*c,d,-1);

vw1=reshape(permute(freqresp(L,w),[3 1 2]),n,k^2);
e=vw-vw1;
er=sqrt(max(sum(abs(e(:,ix)).^2,2)));
fprintf(' matching error: %f\n',er)
vtt=reshape(permute(freqresp(L,tt),[3 1 2]),ntt,k^2);
rtt=zeros(ntt,1);
for i=1:ntt, 
    M=reshape(vtt(i,:),k,k); rtt(i)=min(eig(M+M'));
end
cr=er/100-min(0,min(rtt));
L=L+cr*eye(k);
e=e-repmat(cr*reshape(I,1,k^2),n,1);
fprintf(' corrected by %f to ensure passivity\n',cr)
close(gcf);plot(tt,rtt+cr,'.');grid;pause
ee=sqrt(sum(abs(e(:,ix)).^2,2));
fprintf(' final error: %f\n',max(ee))
close(gcf);plot(w,ee,'.');grid;
L=ltid_tustin(L,1);
[a,b,c,d]=ssdata(L);
L=ss(f0*a,sqrt(f0)*b,sqrt(f0)*c,d);
save(ffnm,'freq','Z_sym','f0','t','aa','G','h','L')   
