
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

        stage('Build Production Docker Image') {
            steps {
                sh '''
                    docker build \
                        --target production \
                        -t aceest-fitness:${BUILD_NUMBER} \
                        -t aceest-fitness:latest \
                        .
                '''
            }
        }
    }

    post {
        success {
            echo 'ACEest Fitness validation passed, containerized tests completed, SonarQube quality gate passed, and production Docker image built.'
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
