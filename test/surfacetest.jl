module SurfacePlotsTests
m=32; n=5;
r = (0:m)/m
theta = reshape(pi*(-n*m:n*m)/m, 1, 2*n*m+1)
z = r * exp(im*theta)
s = r.^(1/n) * exp(im*theta/n)
x = real(z)
y = imag(z)
u = real(s)
v = imag(s)
surface(x,y,u,surfacecolor=randn(size(v)))
end
