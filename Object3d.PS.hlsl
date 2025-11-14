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

struct SpotLight
{
    float32_t4 color; //!< ライトの色
    float32_t3 position; //!< ライトの位置
    float32_t intensity; //!< 輝度
    float32_t3 direction; //!< スポットライトの方向
    float32_t distance; //!< ライトの届く最大距離
    float32_t decay; //!< 減衰率
    float32_t cosAngle; //!< スポットライトの余弦
    float32_t cosFalloffStart;
};

ConstantBuffer<Material> gMaterial : register(b0);
ConstantBuffer<DirectionalLight> gDirectionalLight : register(b1);
ConstantBuffer<Camera> gCamera : register(b2);
ConstantBuffer<PointLight> gPointLight : register(b3);
ConstantBuffer<SpotLight> gSpotLight : register(b4);

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
        // point light 
        float32_t3 pointLightDirection = normalize(input.worldPosition - gPointLight.position);
        float32_t3 halfVector2 = normalize(-pointLightDirection + toEye);
        
        // スペキュラ
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

        //spot
        float32_t3 spotDirection = normalize(input.worldPosition - gSpotLight.position);
        float32_t cosAngle = dot(spotDirection, gSpotLight.direction);
        float32_t falloffFactor = saturate((cosAngle - gSpotLight.cosAngle) / (gSpotLight.cosFalloffStart - gSpotLight.cosAngle));
        
        // スペキュラ
        float32_t3 halfVector3 = normalize(-spotDirection + toEye);
        //float NDotH3 = dot(normalize(gSpotLight.direction), halfVector2);
        float NDotH3 = dot(normalize(input.normal), halfVector3);
        float specularPow3 = pow(saturate(NDotH3), gMaterial.shininess);
       
        float32_t distance3 = length(gSpotLight.position - input.worldPosition); // スポットライトへの距離
        float32_t attenuationFactor = 1.f / (1.f + gSpotLight.decay * pow(distance3 / gSpotLight.distance, 2.f));

        
        float NdotL3 = dot(normalize(input.normal), -spotDirection);
        float cos3 = pow(NdotL3 * 0.5f + 0.5f, 2.0f);

        // 拡散反射
        float32_t3 diffuse3 = gMaterial.color.rgb * textureColor.rgb * gSpotLight.color.rgb * gSpotLight.intensity * attenuationFactor * falloffFactor * cos3;
        // 鏡面反射
        float32_t3 specular3 = gSpotLight.color.rgb * gSpotLight.intensity * specularPow3 * float32_t3(1.0f, 1.0f, 1.0f) * attenuationFactor * falloffFactor;

        
        // --------------------
        
        // 拡散反射+鏡面反射
        //output.color.rgb = diffuse + specular;
        //output.color.rgb = diffuse + specular + diffuse2 + specular2;
        //output.color.rgb = diffuse + specular + diffuse2 + specular2 + spotRGB;
        output.color.rgb = diffuse + specular + diffuse2 + specular2 + diffuse3 + specular3;
        //output.color.rgb = diffuse + specular + diffuse2 + specular2 + diffuse3;

        // アルファは今まで通り
        output.color.a = gMaterial.color.a * textureColor.a;
    }
    else
    { // Lightingしない場合。前回までと同じ演算
        output.color = gMaterial.color * textureColor;
    }

    
    return output;
}


