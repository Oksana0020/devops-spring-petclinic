pipeline {
  agent any

  tools {
    jdk 'JDK17'
    maven 'Maven'
  }

  environment {
    SONAR_TOKEN = credentials('sonar-token')
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

    stage('SonarCloud Analysis') {
      steps {
        bat """
          mvn sonar:sonar ^
          -Dsonar.projectKey=Oksana0020_devops-spring-petclinic ^
          -Dsonar.organization=Oksana0020 ^
          -Dsonar.host.url=https://sonarcloud.io ^
          -Dsonar.login=%SONAR_TOKEN%
        """
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
    }
  }
}