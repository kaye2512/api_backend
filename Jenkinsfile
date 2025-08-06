pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'your-registry.com'
        IMAGE_NAME = 'nestjs-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
        DOCKER_CREDENTIALS_ID = 'docker-registry-credentials'
        GIT_CREDENTIALS_ID = 'git-credentials'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                    env.IMAGE_TAG = "${BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
                }
            }
        }
        
        stage('Install Dependencies') {
            steps {
                script {
                    sh '''
                        npm ci --cache .npm --prefer-offline
                    '''
                }
            }
        }
        
        stage('Lint & Format Check') {
            parallel {
                stage('Linting') {
                    steps {
                        sh 'npm run lint'
                    }
                }
                stage('Format Check') {
                    steps {
                        sh 'npm run format:check'
                    }
                }
            }
        }
        
        stage('Unit Tests') {
            steps {
                sh 'npm run test:cov'
                publishTestResults(
                    testResultsPattern: 'test-results.xml',
                    mergeTestResults: true
                )
                publishCoverage(
                    adapters: [
                        coberturaAdapter('coverage/cobertura-coverage.xml')
                    ],
                    sourceFileResolver: sourceFiles('STORE_LAST_BUILD')
                )
            }
        }
        
        stage('Build Application') {
            steps {
                sh 'npm run build'
                archiveArtifacts artifacts: 'dist/**/*', allowEmptyArchive: false
            }
        }
        
        stage('Security Scan') {
            parallel {
                stage('Dependency Check') {
                    steps {
                        sh 'npm audit --audit-level=moderate'
                    }
                }
                stage('Dockerfile Security') {
                    steps {
                        script {
                            sh '''
                                docker run --rm -i hadolint/hadolint < Dockerfile
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    def image = docker.build("${IMAGE_NAME}:${IMAGE_TAG}")
                    docker.withRegistry("https://${DOCKER_REGISTRY}", "${DOCKER_CREDENTIALS_ID}") {
                        image.push()
                        image.push("latest")
                    }
                }
            }
        }
        
        stage('Integration Tests') {
            steps {
                script {
                    sh '''
                        docker-compose -f docker-compose.test.yml up -d
                        sleep 30
                        npm run test:e2e
                        docker-compose -f docker-compose.test.yml down -v
                    '''
                }
            }
            post {
                always {
                    sh 'docker-compose -f docker-compose.test.yml down -v || true'
                }
            }
        }
        
        stage('Deploy to Staging') {
            when {
                branch 'develop'
            }
            steps {
                script {
                    sh '''
                        docker-compose -f docker-compose.staging.yml down || true
                        docker-compose -f docker-compose.staging.yml pull
                        docker-compose -f docker-compose.staging.yml up -d
                    '''
                }
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                script {
                    input message: 'Deploy to Production?', ok: 'Deploy'
                    sh '''
                        docker-compose -f docker-compose.prod.yml pull
                        docker-compose -f docker-compose.prod.yml up -d --no-deps app
                    '''
                }
            }
        }
        
        stage('Health Check') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                }
            }
            steps {
                script {
                    timeout(time: 5, unit: 'MINUTES') {
                        waitUntil {
                            script {
                                try {
                                    def response = sh(
                                        script: 'curl -f -s http://localhost:3000/health',
                                        returnStdout: true
                                    )
                                    return response.contains('ok')
                                } catch (Exception e) {
                                    return false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            script {
                if (env.BRANCH_NAME == 'main') {
                    slackSend(
                        channel: '#deployments',
                        color: 'good',
                        message: "✅ Deployment successful: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
                    )
                }
            }
        }
        failure {
            script {
                slackSend(
                    channel: '#deployments',
                    color: 'danger',
                    message: "❌ Deployment failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
                )
            }
        }
    }
}