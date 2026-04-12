pipeline {
  agent any

  options {
    buildDiscarder(logRotator(numToKeepStr: '5'))
  }

  environment {
    DOCKER_IMAGE = 'oksana0020/petclinic'
    EC2_HOST     = '16.170.45.98'  // elastic IP
  }

  tools {
    jdk 'JDK17'
    maven 'Maven'
  }

  stages {
    stage('Checkout') {
      steps {
        echo 'Checking out source code from GitHub...'
        checkout scm
        echo 'Source code checkout complete.'
      }
    }

    stage('Build') {
      steps {
        echo 'Building application with Maven (tests skipped)...'
        bat 'mvn -B -DskipTests clean package'
        echo 'Build complete. WAR file ready in target/'
      }
    }

    stage('Test') {
      steps {
        echo 'Running unit and integration tests...'
        bat 'mvn -B verify'
        echo 'All tests completed.'
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
        echo "Building Docker image ${env.DOCKER_IMAGE}:${env.BUILD_NUMBER}..."
        withCredentials([usernamePassword(
          credentialsId: 'dockerhub-credentials',
          usernameVariable: 'DOCKER_USER',
          passwordVariable: 'DOCKER_PASS'
        )]) {
          bat """
            docker build -t %DOCKER_IMAGE%:%BUILD_NUMBER% .
            docker tag %DOCKER_IMAGE%:%BUILD_NUMBER% %DOCKER_IMAGE%:latest
            echo %DOCKER_PASS% | docker login -u %DOCKER_USER% --password-stdin
            docker push %DOCKER_IMAGE%:%BUILD_NUMBER%
            docker push %DOCKER_IMAGE%:latest
          """
        }
      }
    }

    stage('Deploy to AWS EC2') {
      steps {
        echo "Deploying image ${env.DOCKER_IMAGE}:${env.BUILD_NUMBER} to EC2 at ${env.EC2_HOST}..."
        withCredentials([sshUserPrivateKey(
          credentialsId: 'ec2-ssh-key',
          keyFileVariable: 'EC2_KEY',
          usernameVariable: 'EC2_USER'
        )]) {
          bat """
            icacls "%EC2_KEY%" /inheritance:r
            icacls "%EC2_KEY%" /remove:g "BUILTIN\\Users"
            icacls "%EC2_KEY%" /remove:g "NT AUTHORITY\\Authenticated Users"
            icacls "%EC2_KEY%" /grant:r "SYSTEM:R"
            icacls "%EC2_KEY%" /grant:r "Administrators:R"

            ssh -i "%EC2_KEY%" ^
              -o StrictHostKeyChecking=no ^
              -o IdentitiesOnly=yes ^
              %EC2_USER%@%EC2_HOST% ^
              "sudo docker system prune -af --filter 'label!=keep' || true && sudo docker stop petclinic-app || true && sudo docker rm petclinic-app || true && sudo docker pull %DOCKER_IMAGE%:%BUILD_NUMBER% && sudo docker run -d --restart unless-stopped -p 8080:8080 --name petclinic-app %DOCKER_IMAGE%:%BUILD_NUMBER%"
          """
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'target/*.war', fingerprint: true
    }
    success {
      echo "BUILD #${env.BUILD_NUMBER} SUCCESS — ${env.DOCKER_IMAGE}:${env.BUILD_NUMBER} deployed to http://${env.EC2_HOST}:8080"
    }
    failure {
      echo "BUILD #${env.BUILD_NUMBER} FAILED — review console output for details"
    }
  }
}