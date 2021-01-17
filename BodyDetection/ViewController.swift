/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The sample app's main view controller.
*/

import UIKit
import RealityKit
import ARKit
import Combine
import SceneKit

class ViewController: UIViewController, ARSessionDelegate, ARSCNViewDelegate {

    @IBOutlet var arView: ARView!
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var leftAngleLabel: UILabel!
    @IBOutlet weak var rightAngleLabel: UILabel!
    
    // The 3D character to display.
    var character: BodyTrackedEntity?
    let characterOffset: SIMD3<Float> = [-1.0, 0, 0] // Offset the character by one meter to the left
    let characterAnchor = AnchorEntity()
    
    override func viewDidLoad() {
        
    }
    
    private func loadSettingVC(){
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        arView.session.delegate = self
        
        // If the iOS device doesn't support body tracking, raise a developer error for
        // this unhandled case.
        guard ARBodyTrackingConfiguration.isSupported else {
            fatalError("This feature is only supported on devices with an A12 chip")
        }

        // Run a body tracking configration.
        let configuration = ARBodyTrackingConfiguration()
        arView.session.run(configuration)
        
        arView.scene.addAnchor(characterAnchor)
        
        //bring uilabel to front
        self.view.bringSubviewToFront(leftAngleLabel)
        
        // Asynchronously load the 3D character.
        var cancellable: AnyCancellable? = nil
        cancellable = Entity.loadBodyTrackedAsync(named: "character/robot").sink(
            receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    print("Error: Unable to load model: \(error.localizedDescription)")
                }
                cancellable?.cancel()
        }, receiveValue: { (character: Entity) in
            if let character = character as? BodyTrackedEntity {
                // Scale the character to human size
                character.scale = [1.0, 1.0, 1.0]
                self.character = character
                cancellable?.cancel()
            } else {
                print("Error: Unable to load model as BodyTrackedEntity")
            }
        })
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }
            
            // Update the position of the character anchor's position.
            let bodyPosition = simd_make_float3(bodyAnchor.transform.columns.3)
            characterAnchor.position = bodyPosition + characterOffset
            // Also copy over the rotation of the body anchor, because the skeleton's pose
            // in the world is relative to the body anchor's rotation.
            characterAnchor.orientation = Transform(matrix: bodyAnchor.transform).rotation
   
            if let character = character, character.parent == nil {
                // Attach the character to its anchor as soon as
                // 1. the body anchor was detected and
                // 2. the character was loaded.
                characterAnchor.addChild(character)
            }
            
            if let anchor = anchor as? ARBodyAnchor{
                //MARK: - find angle at left knee
                let arSkeleton = anchor.skeleton
            
                //Get the 4x4 matrix transformation from the hip node.
                let leftUpLeg = arSkeleton.modelTransform(for: ARSkeleton.JointName(rawValue: "left_upLeg_joint"))
                let leftKnee = arSkeleton.modelTransform(for: ARSkeleton.JointName(rawValue: "left_leg_joint"))
                let leftFoot = arSkeleton.modelTransform(for: ARSkeleton.JointName(rawValue:"left_foot_joint"))
                
                let leftThigh = positionFromTransform(leftUpLeg!) - positionFromTransform(leftKnee!)
                let leftCalf = positionFromTransform(leftFoot!) - positionFromTransform(leftKnee!)
                
            
                //Compute the angle made by upleg joint and foot joint
                //from the knee joint
                let lAngle = angleBetween(leftThigh, leftCalf) * 180.0 / Float.pi
                leftAngleLabel.text = "angle: \(lAngle)"
                
                //MARK: - find angle at right knee
                let rightUpLeg = arSkeleton.modelTransform(for: ARSkeleton.JointName(rawValue: "right_upLeg_joint"))
                let rightKnee = arSkeleton.modelTransform(for: ARSkeleton.JointName(rawValue: "right_leg_joint"))
                let rightFoot = arSkeleton.modelTransform(for: ARSkeleton.JointName(rawValue:"right_foot_joint"))
                    
                let rightThigh = positionFromTransform(rightUpLeg!) - positionFromTransform(rightKnee!)
                let rightCalf = positionFromTransform(rightFoot!) - positionFromTransform(rightKnee!)
                    
                
                    //Compute the angle made by upleg joint and foot joint
                    //from the knee joint
                let rAngle = angleBetween(rightThigh, rightCalf) * 180.0 / Float.pi
                rightAngleLabel.text = "angle: \(rAngle)"
            }
        }
        
    }

    
    func angleBetween(_ v1:SIMD3<Float>, _ v2:SIMD3<Float>)->Float{
        let lengthv1 = sqrt(v1.x*v1.x + v1.y*v1.y + v1.z*v1.z)
        let lengthv2 = sqrt(v2.x*v2.x + v2.y*v2.y + v2.z*v2.z)
        let dot = dotProduct(left: v1, right: v2) / lengthv1 / lengthv2
        let angle = acos(dot)
        return angle
    }
    
    func dotProduct(left: SIMD3<Float>, right: SIMD3<Float>) -> Float {
        return left.x * right.x + left.y * right.y + left.z * right.z
    }
    
    func positionFromTransform(_ transform: matrix_float4x4) -> SIMD3<Float> {
        let vector = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        return SIMD3(vector)
    }
    
}

