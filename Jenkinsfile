
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

        stage('Run Pytest') {
            steps {
                sh '.venv/bin/python -m pytest -v'
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

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build \
                      -t aceest-fitness:${BUILD_NUMBER} \
                      -t aceest-fitness:latest \
                      .
                '''
            }
        }
    }

    post {
        success {
            echo 'ACEest Fitness checks passed, SonarQube analysis completed, quality gate passed, and Docker image built.'
        }

        failure {
            echo 'Pipeline failed. Review the stage logs and SonarQube quality gate results.'
        }

        always {
            echo 'Jenkins pipeline execution completed.'
        }
    }
}
