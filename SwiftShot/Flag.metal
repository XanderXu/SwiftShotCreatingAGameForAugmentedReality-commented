/*
 Dynamic Flag Simulation
 Copyright (c) 1995, 2018 Apple, Inc.
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 
 Acknowledgments:
 Portions of this Dynamic Flag Simulation utilize the following copyrighted material acknowledged below:
 
 Flag.c, VecF.h, vecM.h, vecP.h, Tmat.h and Tmat.c
 Copyright (c) 1988 Brandyn Webb
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 版权信息
 */

#include <metal_stdlib>
using namespace metal;

/*
 * Weight of a point is always 1. !!!
 * Prefered length of horizontal or vertical spring is always 1. !!!
 * Strength of springs: ( force = strength * displacement )
 * Friction: ( force = fric * vel )
 *
 * NOTE: statements involving fric have been
 * commented out on the assumption that fric is 1.!!!!
 
 一个点的权重总是 1.水平和竖直方向的弹性长度偏好也总是 1！！！！
  弹性长度的公式：( force = strength * displacement )
 摩擦：( force = fric * vel )
 
 注意：涉及摩擦的陈述都是假设fric为1的情况下
 */
//constant float fric = 1;
constant float strength = 10;
constant float strength2 = 20;    // "strength" of tortional constraints
constant float timestep = 1.0f/10.0f;
constant float G = 0.025; // gravity

// We set these as constants to give the compiler more opportunity to optimize.
// Another choice would be to pass these values into the shader at runtime.
// 我们将它们设置为常量，以便为编译器提供更多优化机会。
// 另一种选择是在运行时将这些值传递到着色器。
constant int WIDTH = 32;
constant int HEIGHT = 20;

uint getIndex(uint x, uint y) { return x + y*WIDTH; }

float3 GetPosition(const device float3* positions, uint x, uint y)
{
    return positions[getIndex(x,y)];
}

float3 GetVelocity(const device float3* velocities, uint x, uint y)
{
    return velocities[getIndex(x,y)];
}

// 定义的宏，以方便调用，当满足condition条件时，调用ApplyForce(inVertices, inVelocities, pos, vel, x, y, dx, dy, str)并累加到 force 上
#define APPLY_FORCE(condition, dx, dy, str) \
if(condition) \
{ \
force += ApplyForce(inVertices, inVelocities, pos, vel, x, y, dx, dy, str); \
}

float3 ApplyForce(const device float3* positions,
                  const device float3* velocities,
                  const float3 pos,
                  const float3 vel,
                  const uint x,
                  const uint y,
                  const uint dx,
                  const uint dy,
                  const float constraintStrength)
{
    // Get the distance between the point and its neighbour of interest
    // 获取点与其邻近点之间的距离（3D 空间中的距离，即变形程度向量）
    float3 deltaP = GetPosition(positions, x+dx, y+dy) - pos;
    
    float len = length(deltaP);
    
    float nominalLen = sqrt( float(dx*dx+dy*dy) );//名义上的距离（ 2D平面未拉伸扭转时的距离）
    float sf = (len - nominalLen) * constraintStrength; // Spring force弹力
    
    // Get the velocity difference between the same two points:
    // 获得相同两点之间的速度差异：
    float3 deltaV = GetVelocity(velocities, x+dx, y+dy) - vel;
    
    float invLen = 1/len;//距离的倒数，相当于除以距离（3D 空间的长度）
    
    // Dot that with the positional delta to get spring motion:
    // 将其与位置偏移量点乘，得到弹性运动：
    float sv = dot(deltaP, deltaV) * invLen;
    // 点乘又叫向量的内积、数量积，是一个向量和它在另一个向量上的投影的长度的乘积；是标量。
    // 点乘反映着两个向量的“相似度”，两个向量越“相似”，它们的点乘越大。
    
    
    // 下面是计算力的公式：sf 是布料在 3D 空间变形产生的弹力；sv 是布料点运动速度及方向不同，产生的力；fric 是运动摩擦，这里值取 1；del/invLen 就是变形向量除以长度，即单位长度变形量（变形程度）
    // Force = -(sf + sv * fric) * del/invLen.
    sf += sv;    // friction = 1
    sf *= invLen;
    
    deltaP *= sf;
    // 公式结束
    
    
    return deltaP;
}

struct SimulationData
{
    float3  wind;
};

kernel void updateVertex(const device float3* inVertices [[ buffer(0) ]],
                         device float3* outVertices [[ buffer(1) ]],
                         const device float3 *inVelocities [[ buffer(2) ]],
                         device float3 *outVelocities [[ buffer(3) ]],
                         constant SimulationData &simData [[ buffer(4)]],
                         uint id [[ thread_position_in_grid ]])
{
    const uint x = id % WIDTH;
    const uint y = id / WIDTH;
    
    // Point location, velocity, force (= acceleration, as mass is 1.).
    // 点的位置，速度，力（因为质量是 1，所以加速度的值等于力的值）
    float3 pos = inVertices[id];
    float3 vel = inVelocities[id];
    
    // Start with 0 force.
    // 从 0 的力开始
    float3 force(0,0,0);
    
    // 累加各个方向的计算出来的力，到 force 上
    APPLY_FORCE(x < WIDTH-1,  1, 0, strength);
    APPLY_FORCE(x > 0,       -1, 0, strength);
    
    APPLY_FORCE(y < HEIGHT-1, 0,  1, strength);
    APPLY_FORCE(y > 0,        0, -1, strength);
    
    APPLY_FORCE(x < WIDTH-1 && y < HEIGHT-1,  1,  1, strength);
    APPLY_FORCE(x > 0 && y > 0,              -1, -1, strength);
    
    APPLY_FORCE(x < WIDTH-2,  2, 0, strength2);
    APPLY_FORCE(x > 1      , -2, 0, strength2);
    
    APPLY_FORCE(y < HEIGHT-2, 0,  2, strength2);
    APPLY_FORCE(y > 1,        0, -2, strength2);
    
    // gravity
    // 重力
    force.y += G;
    
    // Add wind contribution
    // 添加风的贡献度
    float3 wind = simData.wind;
    
    if (x < WIDTH-1 && y < HEIGHT-1)
    {
        // 注意此处的 right 和 up 是指向量叉乘的方向，决定了得到法线的正负（朝里面还是朝外面）
        float3 right = GetPosition(inVertices, x+1, y) - pos;
        float3 up = GetPosition(inVertices, x, y+1) - pos;
        float3 n = normalize(cross(right, up));
        
        float3 relativeWind = wind - vel;//相对风速，即风实际速度与旗帜上某个点瞬时速度的差值
        
        // 点乘又叫向量的内积、数量积，是一个向量和它在另一个向量上的投影的长度的乘积；是标量。
        // 点乘反映着两个向量的“相似度”，两个向量越“相似”，它们的点乘越大。
        float f = dot(relativeWind, n) * 0.25;
        
        force += n*f;
    }
    
    // Pin the two left-most corners to the flagpole
    // 将最左侧的两个角点钉在旗杆上
    if ((x == 0 && y == 0) || ((x == 0) && (y == HEIGHT-1)))
        force = 0;
    
    // Cancel force on the right edge of the flag
    // 取消旗帜右边缘的力，不再计算
    if(x == WIDTH-1)
        force = 0;
    
    // move flag
    // 移动旗帜
    float3 v = vel + (force*timestep);//实际速度=原速度+（加速度*时间），force 在这里表示加速度，因为质量是 1，所以加速度===力
    outVelocities[id] = v;
    outVertices[id] = pos + v*timestep;
}

// This function computes the plane normals for the 6 planes touching the
// vertex and averages them as the vertex normal
// 该函数计算顶点周边 6 个平面的法线，并将其平均得到顶点法线
kernel void updateNormal(const device float3* inVertices [[ buffer(0) ]],
                         device float3* outVertices [[ buffer(1) ]],
                         device float3* outNormals [[ buffer(2) ]],
                         uint id [[ thread_position_in_grid ]])
{
    const uint x = id % WIDTH;
    const uint y = id / WIDTH;
    
    const float3 v1 = inVertices[id];
    
    float3 normal(0, 0, 0);
    // 右侧的三个向量，组合求得三个法线
    if (x < WIDTH-1)
    {
        if (y < HEIGHT-1)
        {
            // 注意此处的 right 和 up 是指向量叉乘的方向，决定了得到法线的正负（朝里面还是朝外面）
            float3 right = GetPosition(inVertices, x+1, y+1) - v1;
            float3 up = GetPosition(inVertices, x+1, y) - v1;
            float3 n = normalize(cross(right, up));
            
            normal += n;
            
            right = GetPosition(inVertices, x, y+1) - v1;
            up = GetPosition(inVertices, x+1, y+1) - v1;
            n = normalize(cross(right, up));
            
            normal += n;
        }
        if (y > 0)
        {
            float3 right = GetPosition(inVertices, x+1, y) - v1;
            float3 up = GetPosition(inVertices, x, y-1) - v1;
            float3 n = normalize(cross(right, up));
            
            normal += n;
        }
    }
    
    // 左侧的三个向量，组合求得三个法线
    if (x > 0)
    {
        if (y < HEIGHT-1)
        {
            float3 right = GetPosition(inVertices, x-1, y) - v1;
            float3 up = GetPosition(inVertices, x, y+1) - v1;
            float3 n = normalize(cross(right, up));
            
            normal += n;
        }
        if (y > 0)
        {
            float3 right = GetPosition(inVertices, x-1, y-1) - v1;
            float3 up = GetPosition(inVertices, x-1, y) - v1;
            float3 n = normalize(cross(right, up));
            
            normal += n;
            
            right = GetPosition(inVertices, x, y-1) - v1;
            up = GetPosition(inVertices, x-1, y-1) - v1;
            n = normalize(cross(right, up));
            
            normal += n;
        }
    }
    
    outNormals[id] = normalize(normal);
    outVertices[id] = v1;
}


float3 GetNormal(const device float3* normals, uint x, uint y)
{
    return normals[getIndex(x,y)];
}

#define SMOOTH_FILTER_SIZE 3

kernel void smoothNormal(const device float3* inNormals [[ buffer(0) ]],
                         device float3* outNormals [[ buffer(1) ]],
                         uint id [[ thread_position_in_grid ]])
{
    const int x = id % WIDTH;
    const int y = id / WIDTH;
    
    float3 n(0,0,0);
    
    // 将一个点与其周围 3 个点的法线相加，最后规范化法线 n，得到平滑后的法线
    for(int i = max(0, x - SMOOTH_FILTER_SIZE); i < min(WIDTH, x + SMOOTH_FILTER_SIZE); i++)
    {
        for(int j = max(0, y - SMOOTH_FILTER_SIZE); j < min(HEIGHT, y + SMOOTH_FILTER_SIZE); j++)
        {
            n += GetNormal(inNormals, i, j);
        }
    }
    
    outNormals[id] = normalize(n);
}
