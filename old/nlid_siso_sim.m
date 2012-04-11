function y=nlid_siso_sim(f,q,u,y0,r)
% function y=nlid_siso_sim(f,q,u,y0,r)
%
% Simulation routine for models generated by nlid_siso.m
%
% INPUTS:
%   f  -  msspoly in z=[msspoly('y',m+1);msspoly('u',m+1)]
%   q  -  msspoly in z=[msspoly('y',m+1);msspoly('u',m+1)]
%   u  -  T-by-1 real
%   y0 -  m-by-1 real
%   r  -  positive integer (default r=1)
% OUTPUTS:
%   y  -  T-by-1 real
% DESCRIPTION:
%   Calculate response y=[y(1);...;y(T)] to input u=[u(1);...;u(T)] 
%   of the SISO system f(y(t),y(t-1),...,y(t-m),u(t),...u(t-m))=0, 
%   with initial conditions y0=[y(1);...;y(m)],
%   using r (default r=1) iterations of the Newton method 
%   to solve f(y(t),y(t-1),...,y(t-my),w{t})=0 for y(t) at each step
%   It is assumed that f/q is monotonically increasing with the first
%   argument

if nargin<4, error('4 inputs required'); end
if ~isa(u,'double'), error('input 3 not a "double"'); end
if isempty(u), error('input 3 is empty'); end
[T,nu]=size(u); 
if nu~=1, error('input 3 not a column'); end
if ~isa(y0,'double'), error('input 4 not a "double"'); end
[m,ny]=size(y0);
if ny~=1, error('input 4 not a column'); end
if nargin<5, r=1; end; 
r=max(1,round(real(double(r(1)))));
if ~isa(f,'msspoly'), error('input 1 is not a "msspoly"'); end
if ~isscalar(f), error('input 1 is not scalar'); end
if ~isa(q,'msspoly'), error('input 2 is not a "msspoly"'); end
if ~isscalar(q), error('input 2 is not scalar'); end
z=[msspoly('y',m+1);msspoly('u',m+1)];
z0=z(2:2*m+2);
if ~isfunction(f,z), error('illegal variables in input 1'); end
if ~isfunction(f,z), error('illegal variables in input 1'); end
FF=q*f;
GG=q*diff(f,z(1))-f*diff(q,z(1));
y=zeros(T,1);
y(1:m)=y0;
fprintf('\n nlid_siso_sim.')
t0=m+1;
if t0==1,                   % more effort for the initial value of y
    F=subs(FF,z0,u(1));
    G=subs(GG,z0,u(1));
    y(1)=newton(F,z(1),r+10,0,G);
    t0=2;
end 
for t=t0:T,
    xt=[y(t-1:-1:t-m);u(t:-1:t-m)];
    F=subs(FF,z0,xt);
    G=subs(GG,z0,xt);
    y(t)=newton(F,z(1),r,y(t-1),G);
    if mod(t,100)==0, fprintf('.'); end
end
fprintf('done.\n')
