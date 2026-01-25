pipeline {
  agent any

  tools {
    jdk 'JDK17'
    maven 'Maven'
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build') {
      steps { bat 'mvn -B -DskipTests clean package' }
    }

    stage('Test') {
      steps { bat 'mvn -B test' }
      post {
        always { junit 'target/surefire-reports/*.xml' }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'target/*.jar', fingerprint: true, onlyIfSuccessful: false
    }
  }
}