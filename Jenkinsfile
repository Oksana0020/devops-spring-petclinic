pipeline {
  agent any

  tools {
    jdk 'JDK17'
    maven 'Maven'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build') {
      steps {
        bat 'mvn -B -DskipTests clean package'
      }
    }

    stage('Test') {
      steps {
        bat 'mvn -B verify'
      }
      post {
        always {
          junit 'target/surefire-reports/*.xml'
        }
      }
    }

    stage('SonarCloud Analysis') {
      steps {
        withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
          bat """
            mvn -B org.sonarsource.scanner.maven:sonar-maven-plugin:5.5.0.6356:sonar ^
            -Dsonar.projectKey=Oksana0020_devops-spring-petclinic ^
            -Dsonar.organization=oksana0020 ^
            -Dsonar.host.url=https://sonarcloud.io ^
            -Dsonar.token=%SONAR_TOKEN% ^
            -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml
          """
        }
      }
    }

    stage('Deploy to AWS EC2') {
      steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'EC2_KEY', usernameVariable: 'EC2_USER')]) {
          bat """
            echo Connecting to EC2...
            ssh -o BatchMode=yes -o ConnectTimeout=20 -o StrictHostKeyChecking=no -i "%EC2_KEY%" %EC2_USER%@13.53.134.155 "bash -lc 'echo CONNECTED; sudo docker stop petclinic-app || true; sudo docker rm petclinic-app || true; sudo docker pull oksana0020/petclinic:1.0; sudo docker run -d -p 8080:8080 --name petclinic-app oksana0020/petclinic:1.0; echo DEPLOY_DONE'" < NUL
          """
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'target/*.war', fingerprint: true
    }
  }
}