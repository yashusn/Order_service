// ─────────────────────────────────────────────────────────────────────────────
// Enterprise Declarative Pipeline — order-service
// Stages: Checkout → Build → Test → SonarQube → Quality Gate →
//         OWASP → Docker Build → Trivy → Push ECR → Update GitOps
// ─────────────────────────────────────────────────────────────────────────────
pipeline {
    agent { label 'docker-agent' }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
        timestamps()
    }

    environment {
        APP_NAME        = 'order-service'
        ECR_REGISTRY    = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"
        ECR_REPO        = "${ECR_REGISTRY}/${APP_NAME}"
        GIT_SHA         = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
        IMAGE_TAG       = "${ECR_REPO}:${GIT_SHA}"
        SONAR_TOKEN     = credentials('sonar-token')
        GITOPS_REPO     = 'git@github.com:your-org/gitops-config.git'
        GITOPS_CREDS    = credentials('github-ssh-key')
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                echo "Building branch: ${env.BRANCH_NAME} @ ${env.GIT_SHA}"
            }
        }

        stage('Build') {
            steps {
                sh 'mvn clean package -DskipTests -q'
            }
            post {
                success { archiveArtifacts artifacts: 'target/*.jar', fingerprint: true }
            }
        }

        stage('Unit Tests') {
            steps {
                sh 'mvn test'
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                    jacoco(
                        execPattern: 'target/jacoco.exec',
                        classPattern: 'target/classes',
                        sourcePattern: 'src/main/java',
                        minimumLineCoverage: '80'
                    )
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonar-server') {
                    sh '''
                        mvn sonar:sonar \
                          -Dsonar.projectKey=${APP_NAME} \
                          -Dsonar.branch.name=${BRANCH_NAME}
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('OWASP Dependency Check') {
            steps {
                sh 'mvn org.owasp:dependency-check-maven:check -DfailBuildOnCVSS=7'
            }
            post {
                always {
                    publishHTML(target: [
                        reportDir: 'target',
                        reportFiles: 'dependency-check-report.html',
                        reportName: 'OWASP Dependency Check'
                    ])
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh "docker build -t ${IMAGE_TAG} -t ${ECR_REPO}:latest ."
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh """
                    trivy image \
                      --exit-code 1 \
                      --severity CRITICAL,HIGH \
                      --no-progress \
                      --format table \
                      --output trivy-report.txt \
                      ${IMAGE_TAG}
                """
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-report.txt', allowEmptyArchive: true
                }
            }
        }

        stage('Push to ECR') {
            steps {
                sh """
                    aws ecr get-login-password --region ${AWS_REGION} \
                      | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    docker push ${IMAGE_TAG}
                    docker push ${ECR_REPO}:latest
                """
            }
        }

        stage('Update GitOps Repo') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                }
            }
            steps {
                script {
                    def valuesFile = env.BRANCH_NAME == 'main' ? 'values-staging.yaml' : 'values-dev.yaml'
                    sh """
                        git clone ${GITOPS_REPO} gitops-config
                        cd gitops-config
                        # Bump image tag using yq
                        yq e '.image.tag = "${GIT_SHA}"' -i apps/${APP_NAME}/helm/${valuesFile}
                        git config user.email "jenkins@company.com"
                        git config user.name "Jenkins CI"
                        git add .
                        git commit -m "ci: bump ${APP_NAME} to ${GIT_SHA} [skip ci]"
                        git push origin main
                    """
                }
            }
        }
    }

    post {
        success {
            slackSend(
                channel: '#deployments',
                color: 'good',
                message: "✅ *${APP_NAME}* pipeline passed | Branch: `${env.BRANCH_NAME}` | Tag: `${GIT_SHA}`"
            )
        }
        failure {
            slackSend(
                channel: '#deployments',
                color: 'danger',
                message: "❌ *${APP_NAME}* pipeline FAILED | Branch: `${env.BRANCH_NAME}` | <${env.BUILD_URL}|View Build>"
            )
        }
        always {
            sh "docker rmi ${IMAGE_TAG} || true"
            cleanWs()
        }
    }
}
