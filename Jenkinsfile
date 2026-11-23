
pipeline {
    agent any

    triggers {
        pollSCM('H/2 * * * *')
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Setup Python Environment') {
            steps {
                sh '''
                    python3 --version
                    python3 -m venv .venv
                    .venv/bin/python -m pip install --upgrade pip
                    .venv/bin/python -m pip install -r requirements.txt
                    .venv/bin/python -m pip install ruff
                '''
            }
        }

        stage('Syntax Check') {
            steps {
                sh '.venv/bin/python -m compileall -q app.py tests'
            }
        }

        stage('Run Ruff') {
            steps {
                sh '.venv/bin/ruff check app.py tests'
            }
        }

        stage('Containerized Pytest') {
            steps {
                sh '''
                    mkdir -p reports
                    rm -f reports/pytest-results.xml

                    docker build \
                        --target test \
                        -t aceest-fitness-test:${BUILD_NUMBER} \
                        .

                    docker run --rm \
                        -v "$WORKSPACE/reports:/app/reports" \
                        aceest-fitness-test:${BUILD_NUMBER}
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    def scannerHome = tool 'SonarScanner'

                    withSonarQubeEnv('SonarQube') {
                        sh """
                            "${scannerHome}/bin/sonar-scanner" \
                              -Dsonar.projectKey=aceest-fitness \
                              -Dsonar.projectName="ACEest Fitness Application"
                        """
                    }
                }
            }
        }

        stage('SonarQube Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    script {
                        def qualityGate = waitForQualityGate(
                            abortPipeline: true
                        )

                        echo "SonarQube Quality Gate: ${qualityGate.status}"
                    }
                }
            }
        }

        stage('Build and Publish Docker Image') {
            steps {
                script {
                    def imageName = 'abhishekfopse/aceest-fitness'
                    def buildTag = env.BUILD_NUMBER
                    def shortCommit = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()

                    withCredentials([
                        usernamePassword(
                            credentialsId: 'dockerhub-credentials',
                            usernameVariable: 'DOCKERHUB_USERNAME',
                            passwordVariable: 'DOCKERHUB_TOKEN'
                        )
                    ]) {
                        sh """
                            set -eu

                            trap 'docker logout >/dev/null 2>&1 || true' EXIT

                            echo "\$DOCKERHUB_TOKEN" | docker login \
                                --username "\$DOCKERHUB_USERNAME" \
                                --password-stdin

                            docker build \
                                --target production \
                                -t ${imageName}:${buildTag} \
                                -t ${imageName}:${shortCommit} \
                                -t ${imageName}:latest \
                                .

                            docker push ${imageName}:${buildTag}
                            docker push ${imageName}:${shortCommit}
                            docker push ${imageName}:latest
                        """
                    }

                    echo "Published Docker images to ${imageName}"
                    echo "Build tag: ${buildTag}"
                    echo "Commit tag: ${shortCommit}"
                    echo "Latest tag: latest"
                }
            }
        }
    }

    post {
        success {
            echo 'ACEest Fitness validation passed, containerized tests completed, SonarQube quality gate passed, and Docker images published successfully.'
        }

        failure {
            echo 'Pipeline failed. Review the stage logs, containerized test reports, and SonarQube results.'
        }

        always {
            junit(
                testResults: 'reports/pytest-results.xml',
                allowEmptyResults: true
            )

            archiveArtifacts(
                artifacts: 'reports/**',
                allowEmptyArchive: true
            )

            echo 'Jenkins pipeline execution completed.'
        }
    }
}
