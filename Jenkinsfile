pipeline {
  agent any

  environment {
    DOCKER_IMAGE = 'oksana0020/petclinic'
    EC2_HOST     = '13.53.134.155'
  }

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

    stage('Docker Build & Push') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'dockerhub-credentials',
          usernameVariable: 'DOCKER_USER',
          passwordVariable: 'DOCKER_PASS'
        )]) {
          bat """
            docker build -t %DOCKER_IMAGE%:%BUILD_NUMBER% .
            docker tag %DOCKER_IMAGE%:%BUILD_NUMBER% %DOCKER_IMAGE%:latest
            docker login -u %DOCKER_USER% -p %DOCKER_PASS%
            docker push %DOCKER_IMAGE%:%BUILD_NUMBER%
            docker push %DOCKER_IMAGE%:latest
          """
        }
      }
    }

    stage('Deploy to AWS EC2') {
      steps {
        withCredentials([sshUserPrivateKey(
          credentialsId: 'ec2-ssh-key',
          keyFileVariable: 'EC2_KEY',
          usernameVariable: 'EC2_USER'
        )]) {
          bat """
            icacls "%EC2_KEY%" /inheritance:r /grant:r "%USERNAME%:R"
            ssh -i "%EC2_KEY%" ^^
              -o StrictHostKeyChecking=no ^^
              -o BatchMode=yes ^^
              %EC2_USER%@%EC2_HOST% ^^
              "sudo docker stop petclinic-app || true && sudo docker rm petclinic-app || true && sudo docker pull %DOCKER_IMAGE%:%BUILD_NUMBER% && sudo docker run -d -p 8080:8080 --name petclinic-app %DOCKER_IMAGE%:%BUILD_NUMBER%"
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