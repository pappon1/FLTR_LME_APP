allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    configurations.all {
        resolutionStrategy {
            // Force secure versions of Netty to fix Snyk vulnerabilities
            force("io.netty:netty-handler:4.1.118.Final")
            force("io.netty:netty-codec-http2:4.1.125.Final")
            force("io.netty:netty-codec-http:4.1.125.Final")
            force("io.netty:netty-common:4.1.125.Final")
            force("io.netty:netty-buffer:4.1.125.Final")
            force("io.netty:netty-transport:4.1.125.Final")
            force("io.netty:netty-resolver:4.1.125.Final")
            force("io.netty:netty-codec:4.1.125.Final")
            // Also force a secure version of gRPC Netty if needed
            force("io.grpc:grpc-netty-shaded:1.69.1") 
            // Force secure versions of Protobuf to fix Snyk vulnerabilities
            force("com.google.protobuf:protobuf-java:3.25.5")
            force("com.google.protobuf:protobuf-java-util:3.25.5")
            // Force secure versions of Guava and ErrorProne if needed
            force("com.google.guava:guava:33.3.1-jre")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
