#include "object3d.hlsli"

struct Material
{
    float32_t4 color;
    int32_t enableLighting;
    float32_t shininess;
};

struct DirectionalLight
{
    float32_t4 color; //!< ライトの色
    float32_t3 direction; //!< ライトの向き
    float intensity; //!< 輝度
};

struct Camera
{
    float32_t3 worldPosition;
};

struct PointLight
{
    float32_t4 color; //!< ライトの色
    float32_t3 position; //!< ライトの位置
    float intensity; //!< 輝度
};

ConstantBuffer<Material> gMaterial : register(b0);
ConstantBuffer<DirectionalLight> gDirectionalLight : register(b1);
ConstantBuffer<Camera> gCamera : register(b2);
ConstantBuffer<PointLight> gPointLight : register(b3);

Texture2D<float32_t4> gTexture : register(t0);
SamplerState gSampler : register(s0);

struct PixelShaderOutput
{
    float32_t4 color : SV_TARGET0;
};

PixelShaderOutput main(VertexShaderOutput input)
{
    PixelShaderOutput output;
    float32_t4 textureColor = gTexture.Sample(gSampler, input.texcoord);
    //output.color = gMaterial.color * textureColor;

    //output.color = gMaterial.color;
    if (gMaterial.enableLighting != 0)
    { // Lightingする場合
        
        float32_t3 toEye = normalize(gCamera.worldPosition - input.worldPosition);
        float32_t3 reflectLight = reflect(gDirectionalLight.direction, normalize(input.normal));
        //float RdotE = dot(reflectLight, toEye);
        //float specularPow = pow(saturate(RdotE), gMaterial.shininess); // 反射強度
        //float specularPow = pow(saturate(RdotE), 70); // 反射強度
        float32_t3 halfVector = normalize(-gDirectionalLight.direction + toEye);
        float NDotH = dot(normalize(input.normal), halfVector);
        float specularPow = pow(saturate(NDotH), gMaterial.shininess);

        
        //float cos = saturate(dot(normalize(input.normal), -gDirectionalLight.direction));
        // half lambert
        float NdotL = dot(normalize(input.normal), -gDirectionalLight.direction);
        float cos = pow(NdotL * 0.5f + 0.5f, 2.0f);

        //output.color = gMaterial.color * textureColor * gDirectionalLight.color * cos * gDirectionalLight.intensity;

        // 拡散反射
        float32_t3 diffuse = gMaterial.color.rgb * textureColor.rgb * gDirectionalLight.color.rgb * cos * gDirectionalLight.intensity;
        // 鏡面反射
        float32_t3 specular = gDirectionalLight.color.rgb * gDirectionalLight.intensity * specularPow * float32_t3(1.0f, 1.0f, 1.0f);
        
        
        // -----------------
        
        float32_t3 pointLightDirection = normalize(input.worldPosition - gPointLight.position);
        float32_t3 halfVector2 = normalize(-pointLightDirection + toEye);
        float NDotH2 = dot(normalize(input.normal), halfVector2);
        float specularPow2 = pow(saturate(NDotH2), gMaterial.shininess);
              
        float NdotL2 = dot(normalize(input.normal), -pointLightDirection);
        float cos2 = pow(NdotL2 * 0.5f + 0.5f, 2.0f);

        float32_t distance = length(gPointLight.position - input.worldPosition); // ポイントライトへの距離
        float32_t factor = 1.0f / (distance * distance); // 逆二乗則による減衰係数
                
        // 拡散反射
        float32_t3 diffuse2 = gMaterial.color.rgb * textureColor.rgb * gPointLight.color.rgb * cos2 * gPointLight.intensity * factor;
        // 鏡面反射
        float32_t3 specular2 = gPointLight.color.rgb * gPointLight.intensity * specularPow2 * float32_t3(1.0f, 1.0f, 1.0f) * factor;

        // ------------------------
        
        // 拡散反射+鏡面反射
        //output.color.rgb = diffuse + specular;
        output.color.rgb = diffuse + specular + diffuse2 + specular2;
        // アルファは今まで通り
        output.color.a = gMaterial.color.a * textureColor.a;
    }
    else
    { // Lightingしない場合。前回までと同じ演算
        output.color = gMaterial.color * textureColor;
    }

    
    return output;
}


