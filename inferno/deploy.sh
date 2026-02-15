#!/bin/sh
# Deployment script for Llambo Distributed Cognition Cluster

set -e

echo "=== Llambo Cluster Deployment Script ==="
echo ""

# Configuration
INFERNO_ROOT=${INFERNO_ROOT:-/usr/inferno}
LLAMBO_ROOT=${LLAMBO_ROOT:-$(pwd)}
CLUSTER_CONFIG=${CLUSTER_CONFIG:-cluster-config.yaml}
DEPLOYMENT_MODE=${DEPLOYMENT_MODE:-local}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo "${RED}[ERROR]${NC} $1"
}

# Check if Inferno is installed
check_inferno() {
    log_info "Checking Inferno OS installation..."
    
    if [ ! -d "$INFERNO_ROOT" ]; then
        log_error "Inferno OS not found at $INFERNO_ROOT"
        log_info "Please install Inferno OS or set INFERNO_ROOT environment variable"
        exit 1
    fi
    
    if [ ! -x "$INFERNO_ROOT/Linux/386/bin/emu" ] && [ ! -x "$INFERNO_ROOT/emu" ]; then
        log_error "Inferno emulator not found"
        exit 1
    fi
    
    log_info "Inferno OS found at $INFERNO_ROOT"
}

# Compile Limbo modules
compile_modules() {
    log_info "Compiling Limbo modules..."
    
    cd "$LLAMBO_ROOT/inferno"
    
    # Set up Inferno environment
    export EMU="$INFERNO_ROOT/Linux/386/bin/emu"
    export LIMBO="limbo"
    
    # Compile llambo module
    log_info "  Compiling llambo.b -> llambo.dis"
    if [ -x "$EMU" ]; then
        $EMU sh -c "limbo -o /dis/llambo.dis llambo.b" || {
            log_error "Failed to compile llambo.b"
            exit 1
        }
    else
        log_warn "Emulator not available, skipping compilation"
    fi
    
    # Compile test module
    log_info "  Compiling llambotest.b -> llambotest.dis"
    if [ -x "$EMU" ]; then
        $EMU sh -c "limbo -o /dis/llambotest.dis llambotest.b" || {
            log_warn "Failed to compile llambotest.b (non-critical)"
        }
    fi
    
    # Compile dish integration module
    log_info "  Compiling dish-integration.b -> dish-integration.dis"
    if [ -x "$EMU" ]; then
        $EMU sh -c "limbo -o /dis/dish-integration.dis dish-integration.b" || {
            log_warn "Failed to compile dish-integration.b (non-critical)"
        }
    fi
    
    # Compile limbot module
    log_info "  Compiling limbot.b -> limbot.dis"
    if [ -x "$EMU" ]; then
        $EMU sh -c "limbo -o /dis/limbot.dis limbot.b" || {
            log_warn "Failed to compile limbot.b (non-critical)"
        }
    fi
    
    log_info "Compilation complete"
}

# Deploy to local Inferno instance
deploy_local() {
    log_info "Deploying to local Inferno instance..."
    
    # Create deployment directory
    DEPLOY_DIR="$INFERNO_ROOT/usr/llambo"
    mkdir -p "$DEPLOY_DIR"
    mkdir -p "$DEPLOY_DIR/dis"
    mkdir -p "$DEPLOY_DIR/models"
    
    # Copy modules
    log_info "  Copying modules to $DEPLOY_DIR"
    cp -v llambo.m "$DEPLOY_DIR/"
    cp -v llambo.b "$DEPLOY_DIR/"
    cp -v llambotest.b "$DEPLOY_DIR/"
    cp -v dish-integration.b "$DEPLOY_DIR/"
    cp -v limbot.b "$DEPLOY_DIR/"
    cp -v cluster-config.yaml "$DEPLOY_DIR/"
    cp -v limbot-cli "$DEPLOY_DIR/"
    
    # Copy .dis files if they exist
    if [ -f "/dis/llambo.dis" ]; then
        cp -v /dis/llambo.dis "$DEPLOY_DIR/dis/" || true
    fi
    if [ -f "/dis/dish-integration.dis" ]; then
        cp -v /dis/dish-integration.dis "$DEPLOY_DIR/dis/" || true
    fi
    if [ -f "/dis/limbot.dis" ]; then
        cp -v /dis/limbot.dis "$DEPLOY_DIR/dis/" || true
    fi
    
    log_info "Local deployment complete"
    log_info "Modules deployed to: $DEPLOY_DIR"
}

# Deploy to distributed cluster
deploy_cluster() {
    log_info "Deploying to distributed cluster..."
    
    # Parse cluster configuration
    if [ ! -f "$CLUSTER_CONFIG" ]; then
        log_error "Cluster configuration not found: $CLUSTER_CONFIG"
        exit 1
    fi
    
    # For demonstration, we'll show what would be deployed
    log_info "Cluster configuration:"
    log_info "  Config file: $CLUSTER_CONFIG"
    
    # In production, this would:
    # 1. Parse YAML configuration
    # 2. Connect to cluster management service
    # 3. Deploy modules to each node
    # 4. Initialize orchestrator
    # 5. Start worker nodes
    
    log_warn "Distributed deployment requires cluster infrastructure"
    log_info "Use 'deploy_local' for local testing"
}

# Start orchestrator
start_orchestrator() {
    log_info "Starting Llambo orchestrator..."
    
    EMU="$INFERNO_ROOT/Linux/386/bin/emu"
    
    if [ -x "$EMU" ]; then
        log_info "Launching Inferno emulator with orchestrator..."
        $EMU sh -c "run /dis/llambotest.dis" &
        ORCH_PID=$!
        log_info "Orchestrator started with PID: $ORCH_PID"
        echo $ORCH_PID > /tmp/llambo-orchestrator.pid
    else
        log_error "Cannot start orchestrator: emulator not found"
        exit 1
    fi
}

# Run tests
run_tests() {
    log_info "Running Llambo tests..."
    
    EMU="$INFERNO_ROOT/Linux/386/bin/emu"
    
    if [ -x "$EMU" ]; then
        log_info "Launching test suite..."
        $EMU sh -c "run /dis/llambotest.dis"
    else
        log_error "Cannot run tests: emulator not found"
        exit 1
    fi
}

# Show status
show_status() {
    log_info "Llambo Cluster Status"
    log_info "===================="
    
    if [ -f /tmp/llambo-orchestrator.pid ]; then
        PID=$(cat /tmp/llambo-orchestrator.pid)
        if ps -p $PID > /dev/null 2>&1; then
            log_info "Orchestrator: ${GREEN}RUNNING${NC} (PID: $PID)"
        else
            log_warn "Orchestrator: ${YELLOW}STOPPED${NC}"
        fi
    else
        log_warn "Orchestrator: ${YELLOW}NOT STARTED${NC}"
    fi
    
    log_info ""
    log_info "Deployment directory: $INFERNO_ROOT/usr/llambo"
    log_info "Configuration: $CLUSTER_CONFIG"
}

# Main deployment flow
main() {
    case "${1:-help}" in
        check)
            check_inferno
            ;;
        compile)
            check_inferno
            compile_modules
            ;;
        deploy-local)
            check_inferno
            compile_modules
            deploy_local
            ;;
        deploy-cluster)
            check_inferno
            compile_modules
            deploy_cluster
            ;;
        start)
            start_orchestrator
            ;;
        test)
            run_tests
            ;;
        status)
            show_status
            ;;
        all)
            check_inferno
            compile_modules
            deploy_local
            start_orchestrator
            ;;
        *)
            echo "Usage: $0 {check|compile|deploy-local|deploy-cluster|start|test|status|all}"
            echo ""
            echo "Commands:"
            echo "  check          - Check Inferno OS installation"
            echo "  compile        - Compile Limbo modules"
            echo "  deploy-local   - Deploy to local Inferno instance"
            echo "  deploy-cluster - Deploy to distributed cluster"
            echo "  start          - Start orchestrator"
            echo "  test           - Run test suite"
            echo "  status         - Show cluster status"
            echo "  all            - Run complete deployment"
            echo ""
            echo "Environment variables:"
            echo "  INFERNO_ROOT   - Path to Inferno OS installation (default: /usr/inferno)"
            echo "  LLAMBO_ROOT    - Path to Llambo source (default: current directory)"
            echo "  CLUSTER_CONFIG - Path to cluster config (default: cluster-config.yaml)"
            exit 1
            ;;
    esac
}

# Run main
main "$@"
