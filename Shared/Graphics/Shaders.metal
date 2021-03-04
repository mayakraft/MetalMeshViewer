//
//  shaders.metal
//  MeshViewer
//
//  Created by Robby on 3/3/21.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
  float3 position [[attribute(0)]];
//  float3 normal [[attribute(1)]];
//  float2 texCoords [[attribute(2)]];
};

struct VertexOut {
  float4 position [[position]];
  float4 pos;
  float3 normal;
  float4 eyeNormal;
  float4 eyePosition;
  float2 texCoords;
};

struct Uniforms {
  float4x4 modelViewMatrix;
  float4x4 projectionMatrix;
};

vertex VertexOut vertex_main(VertexIn vertexIn [[stage_in]],
                             constant Uniforms &uniforms [[buffer(1)]]) {
  VertexOut vertexOut;
  vertexOut.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * float4(vertexIn.position, 1);
  vertexOut.pos = float4(vertexIn.position, 1);
//  vertexOut.normal = vertexIn.normal;
//  vertexOut.eyeNormal = uniforms.modelViewMatrix * float4(vertexIn.normal, 0);
  vertexOut.eyePosition = uniforms.modelViewMatrix * float4(vertexIn.position, 1);
//  vertexOut.texCoords = vertexIn.texCoords;
  return vertexOut;
}

fragment float4 fragment_main(VertexOut fragmentIn [[stage_in]]) {
//  return float4(abs(fragmentIn.pos.xyz)*5, 1);
  return float4((fragmentIn.pos.xyz - float3(0, 0.1, 0))*5, 1);
//  return float4(0, 0, 1, 1);
}
