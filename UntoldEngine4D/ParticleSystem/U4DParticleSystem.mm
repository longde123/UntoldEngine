//
//  U4DParticleSystem.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/19/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DParticleSystem.h"
#include "U4DRenderParticleSystem.h"
#include "U4DNumerical.h"
#include "U4DTrigonometry.h"
#include "U4DParticlePhysics.h"
#include "U4DParticleData.h"
#include "U4DParticleEmitterInterface.h"
#include "U4DParticleEmitterLinear.h"
#include "U4DParticleLoader.h"
#include "CommonProtocols.h"

namespace U4DEngine {
    
    U4DParticleSystem::U4DParticleSystem():maxNumberOfParticles(50),hasTexture(false),gravity(0.0,-5.0,0.0),enableAdditiveRendering(true),enableNoise(false),noiseDetail(4.0){
        
        renderManager=new U4DRenderParticleSystem(this);
        
        setShader("vertexParticleSystemShader", "fragmentParticleSystemShader");
        
        particlePhysics=new U4DParticlePhysics();
        
        particleEmitter=nullptr;
        
    }
    
    U4DParticleSystem::~U4DParticleSystem(){
        
        delete particleEmitter;

        delete particlePhysics;
        
        removeAllParticles();
        
    }
    
    void U4DParticleSystem::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        renderManager->render(uRenderEncoder);
        
    }
    
    void U4DParticleSystem::update(double dt){
        
        particleRenderDataContainer.clear();

        U4DEntity *child=this->getLastChild();
        
        while (child!=nullptr) {

            U4DParticle *particle=dynamic_cast<U4DParticle*>(child);

            if (particle) {

                if(particle->particleData.life>0.0){

                    //update particle information
                    particlePhysics->updateForce(particle,gravity,dt);
                    
                    particlePhysics->integrate(particle, dt);
                    
                    particle->particleData.color=particle->particleData.color+particle->particleData.deltaColor*dt;

                    //load the info of the particle into the vector
                    PARTICLERENDERDATA particleRenderData;

                    particleRenderData.color=particle->particleData.color;

                    particleRenderData.absoluteSpace=(particle->getLocalSpace()*particle->getParent()->getAbsoluteSpace()).transformDualQuaternionToMatrix4n();

                    particleRenderDataContainer.push_back(particleRenderData);

                    particle->particleData.life=particle->particleData.life-dt;

                    particle->clearForce();
                    
                }else{

                    //particle is dead
                
                    particleEmitter->decreaseNumberOfEmittedParticles();

                    //remove the node from the scenegraph
                    removeParticleContainer.push_back(particle);

                }

            }

            child=child->getPrevSibling();

        }

        removeDeadParticle();
    }
    
    bool U4DParticleSystem::loadParticleSystem(const char* uModelName, const char* uBlenderFile, PARTICLESYSTEMDATA &uParticleSystemData){
        
        U4DParticleLoader *loader=U4DParticleLoader::sharedInstance();
        
        if(loader->loadDigitalAssetFile(uBlenderFile) && loader->loadAssetToMesh(this,uModelName)){
            
            //max number of particles
            maxNumberOfParticles=uParticleSystemData.maxNumberOfParticles;
            
            //gravity
            gravity=uParticleSystemData.gravity;
            
            enableAdditiveRendering=uParticleSystemData.enableAdditiveRendering;
            
            enableNoise=uParticleSystemData.enableNoise;
            
            noiseDetail=uParticleSystemData.noiseDetail;
            
            initializeParticleEmitter(uParticleSystemData);
            
            return true;
        }
        
        return false;
        
        
    }
    
    void U4DParticleSystem::initializeParticleEmitter(PARTICLESYSTEMDATA &uParticleSystemData){
        
        //get the particle emitter
        
        particleEmitter=emitterFactory.createEmitter(uParticleSystemData.particleSystemType);
        
        if (particleEmitter!=nullptr) {
            
            U4DParticleData particleData;
            
            //color
            particleData.startColor=uParticleSystemData.particleStartColor;
            particleData.startColorVariance=uParticleSystemData.particleStartColorVariance;
            
            particleData.endColor=uParticleSystemData.particleEndColor;
            particleData.endColorVariance=uParticleSystemData.particleEndColorVariance;
            
            //position
            particleData.positionVariance=uParticleSystemData.particlePositionVariance;
            
            //angle
            particleData.emitAngle=uParticleSystemData.particleEmitAngle;
            particleData.emitAngleVariance=uParticleSystemData.particleEmitAngleVariance;
            
            //speed
            particleData.speed=uParticleSystemData.particleSpeed;
            
            //life
            particleData.life=uParticleSystemData.particleLife;
            
            //particles per emission
            particleEmitter->setNumberOfParticlesPerEmission(uParticleSystemData.numberOfParticlesPerEmission);
            
            //emit continuously
            particleEmitter->setEmitContinuously(uParticleSystemData.emitContinuously);
            
            //emission rate
            particleEmitter->setParticleEmissionRate(uParticleSystemData.emissionRate);
            
            //torus major radius
            particleData.torusMajorRadius=uParticleSystemData.torusMajorRadius;
            
            //torus minor radius
            particleData.torusMinorRadius=uParticleSystemData.torusMinorRadius;
            
            //sphere radius
            particleData.sphereRadius=uParticleSystemData.sphereRadius;
            
            particleEmitter->setParticleSystem(this);
            
            particleEmitter->setParticleData(particleData);
            
        }
        
    }
    
    void U4DParticleSystem::play(){
        particleEmitter->play();
    }
    
    void U4DParticleSystem::stop(){
        
        particleEmitter->stop();
        
        removeAllParticles();
        
    }
    
    
    void U4DParticleSystem::setMaxNumberOfParticles(int uMaxNumberOfParticles){
        
        maxNumberOfParticles=uMaxNumberOfParticles;
        
    }
    
    int U4DParticleSystem::getMaxNumberOfParticles(){
        
        return maxNumberOfParticles;
    }
    
    
    int U4DParticleSystem::getNumberOfEmittedParticles(){
        
        return particleEmitter->getNumberOfEmittedParticles();
    }
    
    void U4DParticleSystem::setHasTexture(bool uValue){
        
        hasTexture=uValue;
    }
    
    bool U4DParticleSystem::getHasTexture(){
        
        return hasTexture;
        
    }
    
    std::vector<PARTICLERENDERDATA> U4DParticleSystem::getParticleRenderDataContainer(){
        
        return particleRenderDataContainer;
        
    }
    
    void U4DParticleSystem::removeDeadParticle(){

        //remove node from tree
        for(auto n:removeParticleContainer){
            
            U4DEntity *parent=n->getParent();
            
            parent->removeChild(n);
            
        }
        
        //destruct the object
        for (int i=0; i<removeParticleContainer.size(); i++) {
            
            delete removeParticleContainer.at(i);
            
        }
        
        removeParticleContainer.clear();
        
    }
    
    void U4DParticleSystem::removeAllParticles(){
        
        U4DEntity *child=this->getLastChild();
        
        while (child!=nullptr) {
            
            U4DParticle *particle=dynamic_cast<U4DParticle*>(child);
            
            if (particle) {
                
                removeParticleContainer.push_back(particle);
                
            }
            
            child=child->getPrevSibling();
        }
        
        removeDeadParticle();
        
    }
    
    bool U4DParticleSystem::getEnableAdditiveRendering(){
        
        return enableAdditiveRendering;
    }
    
    bool U4DParticleSystem::getEnableNoise(){
        
        return enableNoise;
    }
    
    float U4DParticleSystem::getNoiseDetail(){
        
        return noiseDetail;
    }
    
}
