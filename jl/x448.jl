# ed448.jl gives some modular arithmetics modulo 2^448-2^224-1 and the point
# addition and scalar multiplication on Edwards curve448. The computation is
# implemented with the intention of implementing it on top of an FPGA.

# Carry saved adder.
function csa(a,b,c,carry_in=0)
    s = (a ⊻ b) ⊻ c
    c = (((a & b) | (a & c) | (b & c)) << 1) | carry_in
    return (s, c)
end

# Modular addition of two numbers modulo p=2^448-2^224-1.
function addmod_448(a, b)
    #   return (a + b) % (BigInt(2)^448-BigInt(2)^224-1)
    p = BigInt(2)^448-BigInt(2)^224-1
    zs, zc = csa(a, b, ~p & (BigInt(2)^448-1), 1)
    sel = ((zs+zc) >> 448) != 0 ? 1 : 0
    return (sel == 1) ? (zs+zc) & (BigInt(2)^448-1) : a+b
end

# Modular subtraction of two numbers in 0:2^255-20 modulo p=2^448-2^224-1.
function submod_448(a, b)
    #   t = (a - b) % (BigInt(2)^448-BigInt(2)^224-1)
    #   return (t < 0) ? t + (BigInt(2)^448-BigInt(2)^224-1) : t
    p = BigInt(2)^448-BigInt(2)^224-1
    zs, zc = csa(a, ~b & (BigInt(2)^448-1), 0)
    ws, wc = csa(a, ~b & (BigInt(2)^448-1), p)
    sel = ((zs+zc+1) >> 448) != 0 ? 1 : 0
    return (sel == 1) ? (zs+zc+1) & (BigInt(2)^448-1) : (ws+wc+1) & (BigInt(2)^448-1)
end

# Modular multiplication of two numbers modulo p=2^448-2^224-1.
# with radix-8 interleave.
function multmod_448(x, y)
    #    return (x*y) % (BigInt(2)^448-BigInt(2)^224-1)
    p = BigInt(2)^448-BigInt(2)^224-1
    lut1 = [(0,0), (y,0), (y<<1, 0), (y<<1, y),
            (y<<2, 0), (y<<2, y), (y<<2, y<<1),
            csa(y<<2,y<<1,y)]
    lut2 = [i*8*(BigInt(2)^224+1) for i=0:23]
    s = c = n = BigInt(0)
    for i in 150:-1:1
        ms, mc = lut1[(x >> (3*i-3)) + 1]
        x = x % BigInt(2)^(3*i-3)
        s1 = 8*(s % BigInt(2)^448)
        c1 = 8*(c % BigInt(2)^448)
        s2 = (s1 ⊻ ms) ⊻ c1
        c2 = ((s1 & ms) | (s1 & c1) | (ms & c1)) << 1
        s3 = (s2 ⊻ mc) ⊻ c2
        c3 = ((s2 & mc) | (s2 & c2) | (mc & c2)) << 1
        s = (s3 ⊻ n) ⊻ c3
        c = ((s3 & n) | (s3 & c3) | (n & c3)) << 1
        n = lut2[(s >> 448) + (c >> 448) + 1]
    end
    # TODO better reduction
    # s c = (s[447:0]+(BigInt(2)^224+1)*(s>>448), c[447:0]+(BigInt(2)^224+1)*(c>>448))
    s, c = csa((s % BigInt(2)^448), (c % BigInt(2)^448), n>>3)
    n = lut2[(s >> 448) + (c >> 448) + 1]
    #println("1st reduce $(s>>446) $(c>>446)")
    s, c = csa((s % BigInt(2)^448), (c % BigInt(2)^448), n>>3)
    z = s + c
    #println("2nd reduce $(s>>446) $(c>>446) $(z>>446)")
    if (z > p)
        z -= p
    end
    return z
end

# Point addition of two points on twisted Edwards curve 448 where
# points are represented with (x, y, t, z) cordinates. If affine variable
# is true, then the result is affinized i.e. z=1.
function point_add_448(x1,y1,t1,z1,x2,y2,t2,z2; affine=false)
    a = multmod_448(x1, x2)
    b = multmod_448(y1, y2)
    c = multmod_448(t1, t2)
    k = BigInt(2)^448-BigInt(2)^224-1-39081
    c = multmod_448(k, c)
    d = multmod_448(z1, z2)

    r1 = addmod_448(x1, y1)
    r2 = addmod_448(x2, y2)
    r3 = addmod_448(a, b)
    r4 = multmod_448(r1, r2)

    e = submod_448(r4, r3)
    f = submod_448(d, c)
    g = addmod_448(d, c)
    h = submod_448(b, a)

    x3 = multmod_448(e, f)
    y3 = multmod_448(g, h)
    t3 = multmod_448(e, h)
    z3 = multmod_448(f, g)

    if (affine == true)
        zinv = invmod_448_M(z3)
        x3 = multmod_448(x3, zinv)
        y3 = multmod_448(y3, zinv)
        t3 = multmod_448(x3, y3)
        z3 = BigInt(1)
    end

    return (x3, y3, t3, z3)
end

function even(x)
    return ((x & 1) == 0) ? true : false
end

function isignbit(x)
    return (x < 0) ? 1 : 0
end

function bitsize(M)
    if (M < 0)
        M = -M
    end
    return length(string(M,base=2))
end

# Montgomery modular inverse.
# Input X in 1:M-1 and M
# Output Lrs in 1:M-1 where Lrs = Xinv 2^n mod M
#  if real_inverse is false, then n = bitsize(M) else n = 0
#  i.e. when real_inverse is true, return the real inverse instead of
#  the almost inverse.
function inv_montgomery(X, M; real_inverse=false)
    # Phase1
    k = -bitsize(M)
    Luv = BigInt(0)
    Ruv = BigInt(X) << 1
    Lrs = BigInt(0)
    Rrs = BigInt(1)
    Luv = (Luv>>1)+Ruv
    Ruv = M
    Lrs = Lrs + Rrs
    Rrs = 0
    while true
        # println("Luv $(Luv) Ruv $(Ruv) Lrs $(Lrs) Rrs $(Rrs) k $(k)")
        SLuv, SRuv = isignbit(Luv), isignbit(Ruv)
        if (even(Luv>>1))
            if Luv == 0 # SLuv == isignbit(-Luv)
                break
            end
            Luv = Luv>>1
            Rrs = Rrs<<1
            k = k+1
        else
            tmpuv = Luv>>1
            tmprs = Lrs
            Lrs = Lrs + Rrs
            if (SLuv ⊻ SRuv) == 1
                Luv = (Luv>>1)+Ruv
            else
                Luv = (Luv>>1)-Ruv
            end
            k = k+1
            ctrl = ((~SLuv & ~SRuv) | (~SLuv & SRuv)) & 1
            if isignbit(Luv) == ctrl
                Ruv = tmpuv
                Rrs = tmprs<<1
            else
                Rrs = Rrs<<1
            end
        end
    end
    # Here we have Lrs == M
    Lrs = Lrs-Rrs
    Rrs = M
    if isignbit(Lrs) == 1
        Lrs = Lrs + Rrs
    end

    # Phase 2
    if (real_inverse)
        k = k + bitsize(M)
    end

    while (k != 0)
        # println("Phase2 Lrs $(Lrs) Rrs $(Rrs) k $(k)")
        k = k - 1
        if even(Lrs)
            Lrs = Lrs>>1
        else
            Lrs = (Lrs+Rrs)>>1
        end
    end
    return Lrs
end

# Modular inverse modulo 2^448-2^224-1 with Montgomery modular inverse.
function invmod_448_M(x)
    p = BigInt(2)^448-BigInt(2)^224-1
    iM = inv_montgomery(x, p, real_inverse=true)
    return iM
end

BasePoint_448=(BigInt(0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa955555555555555555555555555555555555555555555555555555555), BigInt(0xae05e9634ad7048db359d6205086c2b0036ed7a035884dd7b7e36d728ad8c4b80d6565833a2a3098bbbcb2bed1cda06bdaeafbcdea9386ed))

function double_448(x)
    u, v = (x[1], x[2])
    t = multmod_448(u, v)
    d = point_add_448(u, v, t, 1, u, v, t, 1, affine=true)
    return d[1], d[2]
end

function gen_precomp_448()
    plist=[]
    ppow=BasePoint_448
    fx=open("../x448/x_precomp_448.dat", "w")
    fy=open("../x448/y_precomp_448.dat", "w")
    ft=open("../x448/t_precomp_448.dat", "w")
    for j in 1:112
        println("round $(j)")
        u, v = ppow
        s = multmod_448(u, v)
        x, y, t = (u, v, s)
        for i in 1:16
            if (i==1)
                write(fx, string(0,base=16,pad=112))
                write(fy, string(1,base=16,pad=112))
                write(ft, string(0,base=16,pad=112))
            elseif (i==2)
                write(fx, string(u,base=16,pad=112))
                write(fy, string(v,base=16,pad=112))
                write(ft, string(s,base=16,pad=112))
            else
                x, y, t, z = point_add_448(x, y, t, 1, u, v, s, 1, affine=true)
                write(fx, string(x,base=16,pad=112))
                write(fy, string(y,base=16,pad=112))
                write(ft, string(t,base=16,pad=112))
            end
            write(fx, "\n")
            write(fy, "\n")
            write(ft, "\n")
        end
        ppow = double_448(double_448(double_448(double_448(ppow))))
    end
    close(fx)
    close(fy)
    close(ft)
end

# Load precomputed radix-16 lookup table of the scalar multiplications of
# the base point on curve448.
# The nth line of each files is the x,y,t-coordinates of (i*16^j)B expressed in
# 112 hexadecimal digits where i = n %16, j = n ÷ 16 and B is the base point.
function load_precomp_points()
    fx=open("../x448/x_precomp_448.dat", "r")
    fy=open("../x448/y_precomp_448.dat", "r")
    ft=open("../x448/t_precomp_448.dat", "r")
    xlines=readlines(fx)
    ylines=readlines(fy)
    tlines=readlines(ft)
    global x_precomp_data=map(x -> parse(BigInt,x,base=16), xlines)
    global y_precomp_data=map(x -> parse(BigInt,x,base=16), ylines)
    global t_precomp_data=map(x -> parse(BigInt,x,base=16), tlines)
    close(fx)
    close(fy)
    close(ft)
end

# Scalar multiplication of the base point on curve448 with the 16-radix
# precomputed lookup table of scalar multiplications.
# Call load_precomp_points() before calling this function.
function scalarmultB(k)
    kl = [(k >> (4*i)) % 16 for i in 0:111]

    # k0 B from lut
    px = x_precomp_data[1+kl[1]]
    py = y_precomp_data[1+kl[1]]
    pt = t_precomp_data[1+kl[1]]
    pz = BigInt(1)
    for i in 2:112
        # k_n 16^n B from lut
        qx = x_precomp_data[1+(i-1)*16+kl[i]]
        qy = y_precomp_data[1+(i-1)*16+kl[i]]
        qt = t_precomp_data[1+(i-1)*16+kl[i]]
	qz = BigInt(1)
        # p = p + q
        #println("$(i): px $(px) py $(py) qx $(qx) qy $(qy)")
	px, py, pt, pz = point_add_448(px, py, pt, pz, qx, qy, qt, qz,
                                       affine=(i == 112))
    end
    return px, py, pz
end

# Scalar multiplication of given point with Montgomery ladder.
function scalarmult(k, bx, by, bz)
    n = bitsize(k)
    bt = multmod_448(bx, by)

    r0x, r0y, r0t, r0z = (bx, by, bt, bz)
    r1x, r1y, r1t, r1z = point_add_448(bx, by, bt, bz, bx, by, bt, bz)
    for i in n-2:-1:0
        if (((k>>i)&1) == 1)
            r0x, r0y, r0t, r0z = point_add_448(r0x, r0y, r0t, r0z, r1x, r1y, r1t, r1z, affine=(i==0))
            r1x, r1y, r1t, r1z = point_add_448(r1x, r1y, r1t, r1z, r1x, r1y, r1t, r1z)
        else
            r1x, r1y, r1t, r1z = point_add_448(r0x, r0y, r0t, r0z, r1x, r1y, r1t, r1z)
            r0x, r0y, r0t, r0z = point_add_448(r0x, r0y, r0t, r0z, r0x, r0y, r0t, r0z, affine=(i==0))
        end
    end
    return r0x, r0y, r0z
end
    
