// Advanced PowerEdge Client - Modern JavaScript Application
class PowerEdgeApp {
    constructor() {
        this.wsUrl = `ws://${window.location.hostname}:8765`;
        this.apiUrl = `http://${window.location.hostname}:5000`;
        this.ws = null;
        this.reconnectInterval = 5000;
        this.maxReconnectAttempts = 10;
        this.reconnectAttempts = 0;
        this.startTime = Date.now();
        this.currentSection = 'dashboard';
        this.isSidebarCollapsed = false;
        this.sourceData = {};
        this.eventData = [];
        
        // Source configuration with icons and priorities
        this.sourceConfig = {
            'rede': { icon: '🏠', name: 'Electric Grid', priority: 1, color: '#4ecdc4' },
            'solar': { icon: '☀️', name: 'Solar Power', priority: 2, color: '#45b7d1' },
            'gerador': { icon: '⚡', name: 'Generator', priority: 3, color: '#ff6b6b' },
            'ups': { icon: '🔋', name: 'UPS/Battery', priority: 4, color: '#9b59b6' }
        };
        
        this.init();
    }

    async init() {
        this.setupEventListeners();
        this.connectWebSocket();
        await this.loadInitialData();
        this.startPeriodicUpdates();
        this.updateSystemUptime();
        
        // Initialize system health monitoring
        this.lastDataReceived = Date.now();
        this.startSystemHealthMonitoring();
        
        // Start uptime timer
        this.startUptimeTimer();
        
        // Initialize notifications
        this.showNotification('PowerEdge system started', 'success');
        
        // Check for mobile and adjust sidebar
        if (window.innerWidth <= 1024) {
            this.toggleSidebar(true);
        }
    }

    startSystemHealthMonitoring() {
        // Monitor system health every 30 seconds
        setInterval(() => {
            this.monitorSystemHealth();
        }, 30000);
    }

    startPeriodicUpdates() {
        // Load configuration first to get the correct interval
        this.loadConfiguration().then(() => {
            // Use configuration interval or default of 5 seconds
            const interval = (this.currentConfig?.intervalo_leitura || 5) * 1000;
            this.currentUpdateInterval = interval;
            
            // Update events based on configuration
            this.updateInterval = setInterval(() => {
                if (this.currentSection === 'eventos') {
                    this.loadEventData();
                } else if (this.currentSection === 'dashboard') {
                    this.loadRecentEvents();
                }
            }, interval);
        });
        
        // Update system uptime every second (independent of configuration)
        setInterval(() => {
            this.updateSystemUptime();
        }, 1000);
    }

    startUptimeTimer() {
        // Update uptime every second
        setInterval(() => {
            if (this.serverUptimeSeconds !== undefined) {
                this.serverUptimeSeconds += 1;
                this.updateSystemUptime();
            }
        }, 1000);
    }

    setupEventListeners() {
        // Sidebar toggle
        document.querySelector('.sidebar-toggle').addEventListener('click', () => {
            this.toggleSidebar();
        });

        // Menu navigation
        document.querySelectorAll('.menu-item').forEach(item => {
            item.addEventListener('click', (e) => {
                e.preventDefault();
                const href = item.getAttribute('href');
                if (href) {
                    const section = href.replace('#', '');
                    this.showSection(section);
                }
            });
        });

        // Filter controls
        const filtroFonte = document.getElementById('filtro-fonte');
        const filtroTipo = document.getElementById('filtro-tipo');
        
        if (filtroFonte) {
            filtroFonte.addEventListener('change', () => this.loadEventData());
        }
        
        if (filtroTipo) {
            filtroTipo.addEventListener('change', () => this.loadEventData());
        }

        // Statistics period selector
        const statsPeriodo = document.getElementById('stats-periodo');
        if (statsPeriodo) {
            statsPeriodo.addEventListener('change', () => {
                if (this.currentSection === 'estatisticas') {
                    this.loadStatistics();
                }
            });
        }

        // Statistics source filter
        const statsSource = document.getElementById('stats-source');
        if (statsSource) {
            statsSource.addEventListener('change', () => {
                if (this.currentSection === 'estatisticas') {
                    this.loadStatistics();
                }
            });
        }

        // Setup statistics period listener with delay (for dynamic content)
        setTimeout(() => {
            const delayedStatsPeriodo = document.getElementById('stats-periodo');
            if (delayedStatsPeriodo && !delayedStatsPeriodo.hasAttribute('data-listener-added')) {
                delayedStatsPeriodo.addEventListener('change', () => {
                    if (this.currentSection === 'estatisticas') {
                        this.loadStatistics();
                    }
                });
                delayedStatsPeriodo.setAttribute('data-listener-added', 'true');
            }

            const delayedStatsSource = document.getElementById('stats-source');
            if (delayedStatsSource && !delayedStatsSource.hasAttribute('data-listener-added')) {
                delayedStatsSource.addEventListener('change', () => {
                    if (this.currentSection === 'estatisticas') {
                        this.loadStatistics();
                    }
                });
                delayedStatsSource.setAttribute('data-listener-added', 'true');
            }
        }, 1000);

        // Window resize handler
        window.addEventListener('resize', () => {
            if (window.innerWidth <= 1024 && !this.isSidebarCollapsed) {
                this.toggleSidebar(true);
            } else if (window.innerWidth > 1024 && this.isSidebarCollapsed) {
                this.toggleSidebar(false);
            }
        });

        // Visibility change handler for performance
        document.addEventListener('visibilitychange', () => {
            if (!document.hidden) {
                this.loadStatusData();
                this.loadEventData();
            }
        });
    }

    toggleSidebar(force = null) {
        const sidebar = document.querySelector('.sidebar');
        
        if (force !== null) {
            this.isSidebarCollapsed = force;
        } else {
            this.isSidebarCollapsed = !this.isSidebarCollapsed;
        }
        
        if (this.isSidebarCollapsed) {
            sidebar.classList.add('collapsed');
        } else {
            sidebar.classList.remove('collapsed');
        }
    }

    showSection(sectionName) {
        // Update active menu item
        document.querySelectorAll('.menu-item').forEach(item => {
            item.classList.remove('active');
        });
        
        const activeMenuItem = document.querySelector(`[href="#${sectionName}"]`);
        if (activeMenuItem) {
            activeMenuItem.classList.add('active');
        }

        // Hide all sections
        document.querySelectorAll('.content-section').forEach(section => {
            section.classList.remove('active');
        });

        // Show target section
        const targetSection = document.getElementById(`${sectionName}-section`);
        if (targetSection) {
            targetSection.classList.add('active');
            this.currentSection = sectionName;
            
            // Update header
            this.updateHeader(sectionName);
            
            // Load section-specific data
            this.loadSectionData(sectionName);
        }
    }

    updateHeader(sectionName) {
        const titles = {
            'dashboard': 'Dashboard',
            'fontes': 'Power Sources',
            'eventos': 'Event History',
            'estatisticas': 'Statistics and Reports',
            'configuracoes': 'System Settings'
        };
        
        document.getElementById('page-title').textContent = titles[sectionName] || sectionName;
        document.getElementById('breadcrumb-current').textContent = titles[sectionName] || sectionName;
    }

    async loadSectionData(sectionName) {
        switch (sectionName) {
            case 'dashboard':
                this.updateDashboard();
                break;
            case 'fontes':
                this.loadStatusData();
                break;
            case 'eventos':
                this.loadEventData();
                break;
            case 'estatisticas':
                // Load available sources for the filter before loading statistics
                await this.loadStatusData();
                this.loadStatistics();
                break;
            case 'configuracoes':
                this.loadConfiguration();
                break;
        }
    }

    connectWebSocket() {
        try {
            this.ws = new WebSocket(this.wsUrl);
            
            this.ws.onopen = () => {
                this.updateConnectionStatus(true);
                this.reconnectAttempts = 0; // Reset reconnect attempts on successful connection
            };
            
            this.ws.onmessage = (event) => {
                try {
                    const data = JSON.parse(event.data);
                    this.lastDataReceived = Date.now(); // Track data reception time
                    this.updateRealTimeData(data);
                    this.updateLastUpdate();
                } catch (error) {
                }
            };

            this.ws.onclose = () => {
                this.updateConnectionStatus(false);
                this.scheduleReconnect();
            };

            this.ws.onerror = (error) => {
                this.updateConnectionStatus(false);
            };
        } catch (error) {
            this.updateConnectionStatus(false);
            this.scheduleReconnect();
        }
    }

    scheduleReconnect() {
        if (this.reconnectAttempts < this.maxReconnectAttempts) {
            this.reconnectAttempts++;
            setTimeout(() => this.connectWebSocket(), this.reconnectInterval);
        } else {
            this.showNotification('WebSocket connection failed. Please reload the page.', 'error', 0, true); // Critical alarm
        }
    }

    updateConnectionStatus(connected) {
        const indicator = document.getElementById('connection-indicator');
        const text = document.getElementById('connection-text');
        
        if (connected) {
            indicator.classList.add('connected');
            indicator.classList.remove('disconnected');
            text.textContent = 'Connected';
        } else {
            indicator.classList.remove('connected');
            indicator.classList.add('disconnected');
            text.textContent = 'Disconnected';
        }
    }

    updateLastUpdate() {
        const now = new Date();
        document.getElementById('last-update').textContent = now.toLocaleTimeString('en-US');
    }

    async loadInitialData() {
        await Promise.all([
            this.loadStatusData(),
            this.loadEventData()
        ]);
    }

    async loadStatusData() {
        try {
            const response = await fetch(`${this.apiUrl}/status`);
            const data = await response.json();
            
            this.updateSystemStatus(data);
            this.updateSourceFilters(Object.keys(data.fontes || {}));
            
            if (this.currentSection === 'fontes') {
                this.updateSourceCards(data.fontes || {});
            }
        } catch (error) {
            this.showNotification('Error connecting to server', 'error', 0, true); // Critical alarm
        }
    }

    updateSystemStatus(data) {
        const hardwareStatus = document.getElementById('hardware-status');
        
        hardwareStatus.textContent = 'Hardware Real';
        hardwareStatus.style.color = 'var(--success-600)';
        
        document.getElementById('system-status').textContent = 'Online';
        document.getElementById('system-status').style.color = 'var(--success-600)';
    }

    updateSourceFilters(sources) {
        const filtroFonte = document.getElementById('filtro-fonte');
        if (filtroFonte) {
            const existingOptions = Array.from(filtroFonte.options).map(opt => opt.value);
            
            sources.forEach(source => {
                if (!existingOptions.includes(source)) {
                    const option = document.createElement('option');
                    option.value = source;
                    const config = this.sourceConfig[source];
                    option.textContent = config ? config.name : source.charAt(0).toUpperCase() + source.slice(1);
                    filtroFonte.appendChild(option);
                }
            });
        }

        // Also update statistics source filter
        this.updateStatsSourceFilter(sources);
    }

    updateStatsSourceFilter(sources) {
        const statsSource = document.getElementById('stats-source');
        if (!statsSource) return;
        
        // Get current selection
        const currentValue = statsSource.value;
        
        // Clear existing options except "All Sources"
        const allOption = statsSource.querySelector('option[value=""]');
        statsSource.innerHTML = '';
        if (allOption) {
            statsSource.appendChild(allOption);
        } else {
            const newAllOption = document.createElement('option');
            newAllOption.value = '';
            newAllOption.textContent = 'All Sources';
            statsSource.appendChild(newAllOption);
        }
        
        // Add source options
        sources.forEach(source => {
            const option = document.createElement('option');
            option.value = source;
            const config = this.sourceConfig[source];
            option.textContent = config ? `${config.icon} ${config.name}` : source.charAt(0).toUpperCase() + source.slice(1);
            statsSource.appendChild(option);
        });
        
        // Restore previous selection if it still exists
        if (currentValue && sources.includes(currentValue)) {
            statsSource.value = currentValue;
        }
    }

    updateRealTimeData(data) {
        
        // Check for status changes before updating
        this.checkStatusChanges(data);
        
        if (this.currentSection === 'dashboard') {
            this.updateDashboard(data);
        } else if (this.currentSection === 'fontes') {
            this.updateSourceCards(data);
        }
        
        this.updateQuickStatus(data);
        
        // Store current data for comparison next time
        this.sourceData = { ...data };
        
        // Validate consistency whenever data is updated
        if (Object.keys(this.sourceData).length > 0) {
            this.validateSourceCounting();
        }
    }

    checkStatusChanges(newData) {
        if (!this.sourceData || Object.keys(this.sourceData).length === 0) {
            return; // First time loading, no comparison needed
        }
        
        Object.keys(newData).forEach(source => {
            const oldSource = this.sourceData[source];
            const newSource = newData[source];
            
            if (oldSource && oldSource.estado !== newSource.estado) {
                // Status changed - trigger notification
                this.notifySourceStatusChange(
                    source, 
                    oldSource.estado, 
                    newSource.estado, 
                    newSource.tensao
                );
            }
        });
    }

    async updatePerformanceMetrics() {
        try {
            const response = await fetch(`${this.apiUrl}/estatisticas?periodo=24h`);
            if (!response.ok) return;
            
            const data = await response.json();
            const sistema = data.sistema || {};
            
            this.displayPerformanceMetrics(sistema);
        } catch (error) {
        }
    }

    displayPerformanceMetrics(sistema) {
        // Store server uptime
        this.serverUptimeSeconds = sistema.uptime_sistema || 0;
        
        // Operation Mode - Always hardware real
        const operationMode = document.getElementById('operation-mode');
        const operationDetail = document.getElementById('operation-detail');
        if (operationMode && operationDetail) {
            operationMode.textContent = 'Hardware Real';
            operationMode.className = 'performance-value success';
            operationDetail.textContent = 'Physical sensors active';
        }

        // Events per hour
        const eventsPerHour = document.getElementById('events-per-hour');
        if (eventsPerHour) {
            const rate = (sistema.eventos_por_hora || 0).toFixed(1);
            eventsPerHour.textContent = rate;
            eventsPerHour.className = rate > 10 ? 'performance-value warning' : 'performance-value';
        }

        // WebSocket connections
        const wsConnections = document.getElementById('websocket-connections');
        if (wsConnections) {
            const connections = sistema.conexoes_websocket_ativas || 0;
            wsConnections.textContent = connections;
            wsConnections.className = connections > 0 ? 'performance-value success' : 'performance-value error';
        }

        // Database events
        const dbEvents = document.getElementById('database-events');
        if (dbEvents) {
            const events = sistema.banco_eventos || 0;
            dbEvents.textContent = events.toLocaleString();
            dbEvents.className = 'performance-value';
        }
        
        // Update system uptime
        this.updateSystemUptime();
    }

    updateDashboard(data = this.sourceData) {
        
        if (!data || Object.keys(data).length === 0) {
            return;
        }
        
        const sources = Object.keys(data);
        const activeSources = sources.filter(name => data[name].estado === 'ATIVA').length;
        const failedSources = sources.filter(name => data[name].estado === 'FALHA').length;
        const unstableSources = sources.filter(name => data[name].estado === 'INSTAVEL').length;
        
        // Update overview cards
        document.getElementById('total-sources').textContent = sources.length;
        document.getElementById('active-sources').textContent = activeSources;
        document.getElementById('failed-sources').textContent = failedSources;
        document.getElementById('unstable-sources').textContent = unstableSources; // Update the new card
        
        // Update system uptime
        this.updateSystemUptime();
        
        // Update performance metrics periodically
        if (!this.lastPerformanceUpdate || (Date.now() - this.lastPerformanceUpdate) > 60000) {
            this.updatePerformanceMetrics();
            this.lastPerformanceUpdate = Date.now();
        }
        
        this.updateQuickStatus(data);
        this.loadRecentEvents();
    }

    updateSystemUptime() {
        const uptimeElement = document.getElementById('system-uptime');
        if (uptimeElement) {
            // Use server time if available
            if (this.serverUptimeSeconds) {
                const hours = Math.floor(this.serverUptimeSeconds / 3600);
                const minutes = Math.floor((this.serverUptimeSeconds % 3600) / 60);
                
                if (hours > 0) {
                    uptimeElement.textContent = `${hours}h ${minutes}m`;
                } else if (minutes > 0) {
                    uptimeElement.textContent = `${minutes}m`;
                } else {
                    uptimeElement.textContent = `${Math.floor(this.serverUptimeSeconds)}s`;
                }
            } else {
                // Fallback to local time (only if no server data available)
                const elapsed = Date.now() - this.startTime;
                const hours = Math.floor(elapsed / 3600000);
                const minutes = Math.floor((elapsed % 3600000) / 60000);
                
                if (hours > 0) {
                    uptimeElement.textContent = `${hours}h ${minutes}m`;
                } else if (minutes > 0) {
                    uptimeElement.textContent = `${minutes}m`;
                } else {
                    uptimeElement.textContent = `${Math.floor(elapsed / 1000)}s`;
                }
            }
        }
    }

    async loadEventData() {
        try {
            this.showLoadingState('eventos-section');
            
            const filtroFonte = document.getElementById('filtro-fonte')?.value || '';
            const filtroTipo = document.getElementById('filtro-tipo')?.value || '';
            const filtroPeriodo = document.getElementById('filtro-periodo')?.value || 'all';
            const searchQuery = document.getElementById('eventos-search')?.value?.toLowerCase() || '';
            
            let url = `${this.apiUrl}/eventos?limite=200`;
            
            if (filtroFonte) {
                url += `&fonte=${filtroFonte}`;
            }
            
            // Add date filtering to API call if needed
            if (filtroPeriodo !== 'all') {
                const now = new Date();
                let startDate = new Date();
                
                switch(filtroPeriodo) {
                    case '24h':
                        startDate.setHours(now.getHours() - 24);
                        break;
                    case '7d':
                        startDate.setDate(now.getDate() - 7);
                        break;
                    case '30d':
                        startDate.setDate(now.getDate() - 30);
                        break;
                }
                
                url += `&data_inicio=${startDate.toISOString()}`;
            }
            
            const response = await fetch(url);
            const events = await response.json();
            
            // Apply client-side filtering 
            let filteredEvents = events;
            
            // Filter by type if needed
            if (filtroTipo) {
                filteredEvents = filteredEvents.filter(event => event.tipo === filtroTipo);
            }
            
            // Apply search filter if provided
            if (searchQuery) {
                filteredEvents = filteredEvents.filter(event => {
                    const sourceName = this.sourceConfig[event.fonte]?.name || event.fonte;
                    const eventType = this.translateStatus(event.tipo);
                    const eventDate = new Date(event.data_hora).toLocaleString('en-US');
                    
                    return (
                        sourceName.toLowerCase().includes(searchQuery) ||
                        eventType.toLowerCase().includes(searchQuery) ||
                        eventDate.toLowerCase().includes(searchQuery) ||
                        (event.tensao && event.tensao.toString().includes(searchQuery))
                    );
                });
            }
            
            // Update counts
            document.getElementById('total-events-count').textContent = events.length;
            document.getElementById('filtered-events-count').textContent = filteredEvents.length;
            
            // Store in instance for pagination
            this.allEventData = events;
            this.eventData = filteredEvents;
            
            this.hideLoadingState('eventos-section');
            this.displayEvents(filteredEvents);
            
            // Set up load more button
            const loadMoreBtn = document.getElementById('load-more-events');
            if (loadMoreBtn) {
                // Reset display limit
                this.eventDisplayLimit = 50;
                
                // Show or hide based on if there are more events
                if (filteredEvents.length > this.eventDisplayLimit) {
                    loadMoreBtn.style.display = 'block';
                    loadMoreBtn.onclick = () => this.loadMoreEvents();
                } else {
                    loadMoreBtn.style.display = 'none';
                }
            }
            
        } catch (error) {
            this.hideLoadingState('eventos-section');
            this.showErrorState('eventos-section', 'Failed to load events', error.message);
            this.showNotification('Error loading events', 'error');
        }
    }

    loadMoreEvents() {
        // Increase limit and redisplay
        this.eventDisplayLimit += 50;
        this.displayEvents(this.eventData);
        
        // Hide button if we've shown all events
        if (this.eventDisplayLimit >= this.eventData.length) {
            document.getElementById('load-more-events').style.display = 'none';
        }
    }

    async loadRecentEvents() {
        try {
            const response = await fetch(`${this.apiUrl}/eventos?limite=10`);
            const events = await response.json();
            
            this.displayRecentEvents(events);
        } catch (error) {
        }
    }

    displayEvents(events) {
        const lista = document.getElementById('eventos-lista');
        if (!lista) return;
        
        lista.innerHTML = '';
        
        if (!events || events.length === 0) {
            lista.innerHTML = `
                <div class="empty-state">
                    <p>No events found matching your filters</p>
                </div>
            `;
            return;
        }
        
        // Create header row
        const header = document.createElement('div');
        header.className = 'evento-item evento-header';
        header.innerHTML = `
            <div class="evento-info"><strong>Source & Type</strong></div>
            <div class="evento-data"><strong>Date & Time</strong></div>
        `;
        lista.appendChild(header);
        
        // Only display up to the limit
        const displayEvents = this.eventDisplayLimit 
            ? events.slice(0, this.eventDisplayLimit)
            : events;
        
        displayEvents.forEach(event => {
            const item = this.createEventItem(event);
            lista.appendChild(item);
        });
    }

    displayRecentEvents(events) {
        const container = document.getElementById('recent-events-list');
        if (!container) return;
        
        container.innerHTML = '';
        
        if (!events || events.length === 0) {
            container.innerHTML = '<p>No recent events</p>';
            return;
        }
        
        events.slice(0, 5).forEach(event => {
            const item = this.createRecentEventItem(event);
            container.appendChild(item);
        });
    }

    createEventItem(event) {
        const item = document.createElement('div');
        item.className = `evento-item evento-item-${event.tipo.toLowerCase()}`;
        
        const date = new Date(event.data_hora);
        const formattedDate = date.toLocaleDateString('en-US', { 
            year: 'numeric', 
            month: 'short', 
            day: 'numeric' 
        });
        const formattedTime = date.toLocaleTimeString('en-US', { 
            hour: '2-digit', 
            minute: '2-digit', 
            second: '2-digit',
            hour12: true
        });
        
        const config = this.sourceConfig[event.fonte];
        const sourceName = config?.name || event.fonte.charAt(0).toUpperCase() + event.fonte.slice(1);
        
        // Get appropriate status icon
        let statusIcon = '⚪';
        if (event.tipo === 'ATIVA') statusIcon = '🟢';
        else if (event.tipo === 'FALHA') statusIcon = '🔴';
        else if (event.tipo === 'ERRO') statusIcon = '🟠';
        
        const tensaoTexto = event.tensao ? `${event.tensao.toFixed(1)}V` : '';
        
        item.innerHTML = `
            <div class="evento-info">
                <div class="evento-fonte">${config?.icon || '⚡'} ${sourceName}</div>
                <div class="evento-tipo">
                    <span class="evento-status-badge">${statusIcon}</span>
                    ${this.translateStatus(event.tipo)}
                    ${tensaoTexto ? `<span class="evento-tensao">${tensaoTexto}</span>` : ''}
                </div>
            </div>
            <div class="evento-data">
                <div class="data-calendar">${formattedDate}</div>
                <div class="data-time">${formattedTime}</div>
            </div>
        `;
        
        return item;
    }

    createRecentEventItem(event) {
        const item = document.createElement('div');
        item.className = 'recent-event-item';
        
        const data = new Date(event.data_hora);
        const timeAgo = this.getTimeAgo(data);
        const config = this.sourceConfig[event.fonte];
        
        item.innerHTML = `
            <div class="event-icon">${config?.icon || '⚡'}</div>
            <div class="event-content">
                <div class="event-title">${config?.name || event.fonte} - ${this.translateStatus(event.tipo)}</div>
                <div class="event-time">${timeAgo}</div>
            </div>
        `;
        
        return item;
    }

    getTimeAgo(date) {
        const now = new Date();
        const diffMs = now - date;
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMins / 60);
        const diffDays = Math.floor(diffHours / 24);
        
        if (diffMins < 1) return 'Now';
        if (diffMins < 60) return `${diffMins}m ago`;
        if (diffHours < 24) return `${diffHours}h ago`;
        return `${diffDays}d ago`;
    }

    async loadStatistics() {
        try {
            this.showLoadingState('estatisticas-section');
            
            const periodo = document.getElementById('stats-periodo')?.value || '24h';
            const sourceFilter = document.getElementById('stats-source')?.value || '';
            
            let url = `${this.apiUrl}/estatisticas?periodo=${periodo}`;
            if (sourceFilter) {
                url += `&fonte=${sourceFilter}`;
            }
            
            const response = await fetch(url);
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            const stats = await response.json();
            
            this.hideLoadingState('estatisticas-section');
            this.displayStatistics(stats, sourceFilter);
            
        } catch (error) {
            this.hideLoadingState('estatisticas-section');
            this.showErrorState('estatisticas-section', 'Error loading statistics', error.message);
        }
    }

    displayStatistics(stats, sourceFilter = '') {
        // Clear any existing charts
        this.destroyExistingCharts();
        
        // Display summary cards
        this.displaySummaryCards(stats, sourceFilter);
        
        // Create charts
        this.createAvailabilityChart(stats);
        this.createVoltageChart(stats);
        this.createEventsTimelineChart(stats);
        this.createStatusDistributionChart(stats);
    }

    displaySummaryCards(stats, sourceFilter = '') {
        const container = document.getElementById('stats-cards');
        if (!container) return;
        
        const estatisticas = stats.estatisticas || {};
        const sistema = stats.sistema || {};
        
        // Filter statistics if a specific source is selected
        let filteredEstatisticas = estatisticas;
        if (sourceFilter) {
            filteredEstatisticas = { [sourceFilter]: estatisticas[sourceFilter] };
        }
        
        // Use consistent source counting from real-time data
        const sourceStates = this.countSourceStates();
        
        // Validate counting consistency
        this.validateSourceCounting();
        
        const totalFontes = sourceFilter ? 1 : (sourceStates.totalFontes || sistema.total_fontes || Object.keys(estatisticas).length);
        const fontesAtivas = sourceFilter ? (this.sourceData[sourceFilter]?.estado === 'ATIVA' ? 1 : 0) : sourceStates.fontesAtivas;
        
        const totalEventos = Object.values(filteredEstatisticas).reduce((sum, s) => sum + (s?.total_eventos || 0), 0);
        const disponibilidadeMedia = sourceFilter && filteredEstatisticas[sourceFilter] ? 
            filteredEstatisticas[sourceFilter].disponibilidade :
            (sistema.disponibilidade_sistema || 
            (totalFontes > 0 ? Object.values(filteredEstatisticas).reduce((sum, s) => sum + (s?.disponibilidade || 0), 0) / Object.keys(filteredEstatisticas).length : 0));
        
        // Format uptime based on filter and statistics
        const uptimeStats = sistema.uptime_stats || {};
        const uptimeSeconds = uptimeStats.uptime_seconds || sistema.uptime_sistema || 0;
        
        let uptimeFormatted;
        if (uptimeSeconds === 0 && uptimeStats.last_total_blackout && !sourceFilter) {
            // We're in a total blackout
            uptimeFormatted = '0s';
        } else {
            const uptimeHours = Math.floor(uptimeSeconds / 3600);
            const uptimeMinutes = Math.floor((uptimeSeconds % 3600) / 60);
            const uptimeSecondsRemainder = Math.floor(uptimeSeconds % 60);
            
            if (uptimeHours > 0) {
                uptimeFormatted = `${uptimeHours}h ${uptimeMinutes}m`;
            } else if (uptimeMinutes > 0) {
                uptimeFormatted = `${uptimeMinutes}m ${uptimeSecondsRemainder}s`;
            } else {
                uptimeFormatted = `${uptimeSecondsRemainder}s`;
            }
        }
        
        // Debug logging
        console.log('Uptime calculation:', {
            sourceFilter,
            uptimeStats,
            uptimeType: uptimeStats.uptime_type,
            uptimeSeconds: uptimeSeconds,
            lastFailure: uptimeStats.last_failure,
            lastTotalBlackout: uptimeStats.last_total_blackout
        });
        
        // Generate uptime trend text based on context
        let uptimeTrend = 'Hardware Real';
        if (sourceFilter && uptimeStats.uptime_type === 'source') {
            if (uptimeStats.last_failure) {
                uptimeTrend = 'Since last failure';
            } else {
                uptimeTrend = 'No failures recorded';
            }
        } else if (!sourceFilter && uptimeStats.uptime_type === 'system') {
            if (uptimeStats.last_total_blackout) {
                // Check if we're currently in a blackout (uptime is 0)
                if (uptimeSeconds === 0) {
                    uptimeTrend = 'Total blackout in progress';
                } else {
                    uptimeTrend = 'Since total blackout recovery';
                }
            } else {
                uptimeTrend = 'No total blackout recorded';
            }
        }
        
        // Get source name for filtered view
        const sourceName = sourceFilter ? (this.sourceConfig[sourceFilter]?.name || sourceFilter) : 'All Sources';
        const sourceIcon = sourceFilter ? (this.sourceConfig[sourceFilter]?.icon || '⚡') : '📊';
        
        container.innerHTML = `
            <div class="stats-card summary">
                <h4>${sourceFilter ? `${sourceIcon} ${sourceName}` : 'Monitored Sources'}</h4>
                <div class="value">${totalFontes}</div>
                <div class="trend">${sourceFilter ? `Status: ${this.translateStatus(this.sourceData[sourceFilter]?.estado || 'UNKNOWN')}` : `Active: ${fontesAtivas} | Issues: ${sourceStates.fontesComProblemas}`}</div>
            </div>
            <div class="stats-card summary">
                <h4>${sourceFilter ? 'Source Availability' : 'System Availability'}</h4>
                <div class="value" style="color: ${disponibilidadeMedia >= 90 ? '#059669' : disponibilidadeMedia >= 70 ? '#f59e0b' : '#dc2626'}">${disponibilidadeMedia.toFixed(1)}<span class="unit">%</span></div>
                <div class="trend">${sourceFilter ? `${sourceName} average` : 'Overall average'}</div>
            </div>
            <div class="stats-card summary">
                <h4>Total Events</h4>
                <div class="value">${totalEventos.toLocaleString()}</div>
                <div class="trend">${sourceFilter ? `${sourceName} events` : `${(sistema.eventos_por_hora || 0).toFixed(1)} events/hour`}</div>
            </div>
            <div class="stats-card summary">
                <h4>${sourceFilter ? `Source Uptime` : 'System Uptime'}</h4>
                <div class="value">${uptimeFormatted}</div>
                <div class="trend">${uptimeTrend}</div>
            </div>
            <div class="stats-card summary system-info">
                <h4>System Information</h4>
                <div class="system-details">
                    <div class="system-row">
                        <span>Version:</span>
                        <span>PowerEdge ${sistema.versao || '2.0'}</span>
                    </div>
                    <div class="system-row">
                        <span>Mode:</span>
                        <span style="color: #059669">Hardware Real</span>
                    </div>
                    <div class="system-row">
                        <span>DB Events:</span>
                        <span>${(sistema.banco_eventos || 0).toLocaleString()}</span>
                    </div>
                    <div class="system-row">
                        <span>WS Connections:</span>
                        <span>${sistema.conexoes_websocket_ativas || 0}</span>
                    </div>
                </div>
            </div>
        `;
    }

    createAvailabilityChart(stats) {
        const ctx = document.getElementById('availability-chart');
        if (!ctx) return;
        
        const estatisticas = stats.estatisticas || {};
        const labels = Object.keys(estatisticas).map(fonte => 
            this.sourceConfig[fonte]?.name || fonte
        );
        const data = Object.values(estatisticas).map(s => s.disponibilidade);
        const colors = Object.keys(estatisticas).map(fonte => 
            this.sourceConfig[fonte]?.color || '#6b7280'
        );
        
        this.charts.availability = new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: labels,
                datasets: [{
                    data: data,
                    backgroundColor: colors,
                    borderWidth: 2,
                    borderColor: '#ffffff'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            padding: 15,
                            usePointStyle: true
                        }
                    },
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                return `${context.label}: ${context.parsed}%`;
                            }
                        }
                    }
                }
            }
        });
    }

    createVoltageChart(stats) {
        const ctx = document.getElementById('voltage-chart');
        if (!ctx) return;
        
        const estatisticas = stats.estatisticas || {};
        const labels = Object.keys(estatisticas).map(fonte => 
            this.sourceConfig[fonte]?.name || fonte
        );
        
        this.charts.voltage = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Average Voltage (V)',
                    data: Object.values(estatisticas).map(s => s.tensao_media),
                    backgroundColor: Object.keys(estatisticas).map(fonte => 
                        this.sourceConfig[fonte]?.color + '80' || '#6b728080'
                    ),
                    borderColor: Object.keys(estatisticas).map(fonte => 
                        this.sourceConfig[fonte]?.color || '#6b7280'
                    ),
                    borderWidth: 2
                }, {
                    label: 'Minimum Voltage (V)',
                    data: Object.values(estatisticas).map(s => s.tensao_min),
                    backgroundColor: '#ef444440',
                    borderColor: '#ef4444',
                    borderWidth: 1
                }, {
                    label: 'Maximum Voltage (V)',
                    data: Object.values(estatisticas).map(s => s.tensao_max),
                    backgroundColor: '#10b98140',
                    borderColor: '#10b981',
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'top'
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Voltage (V)'
                        }
                    }
                }
            }
        });
    }

    createEventsTimelineChart(stats) {
        const ctx = document.getElementById('events-timeline');
        if (!ctx) return;
        
        const estatisticas = stats.estatisticas || {};
        const labels = Object.keys(estatisticas).map(fonte => 
            this.sourceConfig[fonte]?.name || fonte
        );
        
        this.charts.timeline = new Chart(ctx, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Active Events',
                    data: Object.values(estatisticas).map(s => s.eventos_ativa),
                    borderColor: '#10b981',
                    backgroundColor: '#10b98120',
                    tension: 0.4,
                    fill: true
                }, {
                    label: 'Failure Events',
                    data: Object.values(estatisticas).map(s => s.eventos_falha),
                    borderColor: '#ef4444',
                    backgroundColor: '#ef444420',
                    tension: 0.4,
                    fill: true
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'top'
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Number of Events'
                        }
                    }
                }
            }
        });
    }

    createStatusDistributionChart(stats) {
        const ctx = document.getElementById('status-distribution');
        if (!ctx) return;
        
        // Usar contagem consistente das fontes
        const sourceStates = this.countSourceStates();
        
        // Validate consistency
        this.validateSourceCounting();
        
        // Include only states that have sources to avoid empty chart
        const labels = [];
        const data = [];
        const backgroundColor = [];
        
        const stateConfig = {
            'ATIVA': { label: 'Active', color: '#10b981' },
            'FALHA': { label: 'Failed', color: '#ef4444' },
            'INSTAVEL': { label: 'Unstable', color: '#f59e0b' },
            'ERRO': { label: 'Error', color: '#6b7280' },
            'DESCONHECIDO': { label: 'Unknown', color: '#9ca3af' }
        };
        
        Object.entries(stateConfig).forEach(([state, config]) => {
            if (sourceStates[state] > 0) {
                labels.push(config.label);
                data.push(sourceStates[state]);
                backgroundColor.push(config.color);
            }
        });
        
        // If there's no data, show message
        if (data.length === 0) {
            ctx.parentElement.innerHTML = '<p class="no-data">No sources monitored</p>';
            return;
        }
        
        this.charts.status = new Chart(ctx, {
            type: 'pie',
            data: {
                labels: labels,
                datasets: [{
                    data: data,
                    backgroundColor: backgroundColor,
                    borderWidth: 2,
                    borderColor: '#ffffff'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            padding: 15,
                            usePointStyle: true
                        }
                    }
                }
            }
        });
    }

    destroyExistingCharts() {
        if (!this.charts) {
            this.charts = {};
            return;
        }
        
        Object.values(this.charts).forEach(chart => {
            if (chart && typeof chart.destroy === 'function') {
                chart.destroy();
            }
        });
        
        this.charts = {};
    }

    showLoadingState(sectionId) {
        const section = document.getElementById(sectionId);
        if (!section) return;
        
        const existing = section.querySelector('.loading-container');
        if (existing) return; // Already showing
        
        const loadingDiv = document.createElement('div');
        loadingDiv.className = 'loading-container';
        loadingDiv.innerHTML = `
            <div class="loading-spinner"></div>
            <p>Loading data...</p>
        `;
        
        section.appendChild(loadingDiv);
    }

    hideLoadingState(sectionId) {
        const section = document.getElementById(sectionId);
        if (!section) return;
        
        const loading = section.querySelector('.loading-container');
        if (loading) {
            loading.remove();
        }
    }

    showErrorState(sectionId, title, details) {
        const section = document.getElementById(sectionId);
        if (!section) return;
        
        // Remove existing error state
        const existing = section.querySelector('.error-container');
        if (existing) existing.remove();
        
        const errorDiv = document.createElement('div');
        errorDiv.className = 'error-container';
        errorDiv.innerHTML = `
            <h3>${title}</h3>
            <p>Unable to load data.</p>
            ${details ? `<div class="error-details">Details: ${details}</div>` : ''}
            <button class="btn btn-primary" onclick="app.loadSectionData('${sectionId.replace('-section', '')}')">
                🔄 Try Again
            </button>
        `;
        
        section.appendChild(errorDiv);
    }

    async loadConfiguration() {
        try {
            const response = await fetch(`${this.apiUrl}/configuracao`);
            const config = await response.json();
            
            this.displayConfiguration(config);
        } catch (error) {
            this.showNotification('Error loading configuration', 'error');
        }
    }

    displayConfiguration(config) {
        // Store loaded configuration
        this.currentConfig = config;
        
        // Update form fields
        const intervalInput = document.getElementById('intervalo-leitura');
        if (intervalInput) {
            intervalInput.value = config.intervalo_leitura || 1.0;
        }

        const percentualInput = document.getElementById('percentual-instabilidade');
        if (percentualInput) {
            percentualInput.value = config.percentual_instabilidade || 70;
        }

        // Update thresholds per source
        const thresholds = config.thresholds || {};
        const thresholdInputs = {
            'rede': document.getElementById('threshold-rede'),
            'solar': document.getElementById('threshold-solar'),
            'gerador': document.getElementById('threshold-gerador'),
            'ups': document.getElementById('threshold-ups')
        };

        Object.entries(thresholdInputs).forEach(([fonte, input]) => {
            if (input) {
                input.value = thresholds[fonte] || this.getDefaultThreshold(fonte);
            }
        });

        // Update notification checkboxes
        const notifyFailures = document.getElementById('notify-failures');
        const notifyRecovery = document.getElementById('notify-recovery');
        if (notifyFailures) {
            notifyFailures.checked = config.notify_failures !== false;
        }
        if (notifyRecovery) {
            notifyRecovery.checked = config.notify_recovery !== false;
        }

        // Update system information
        const hardwareInfo = document.getElementById('hardware-info');
        if (hardwareInfo) {
            hardwareInfo.textContent = 'Raspberry Pi + ADS1115';
        }

        // Add event listener to save configuration
        const saveButton = document.querySelector('.config-form .btn-primary');
        if (saveButton) {
            saveButton.onclick = () => this.saveConfiguration();
        }
        
        // Apply configurations immediately
        this.applyConfiguration(config);
    }

    getDefaultThreshold(fonte) {
        const defaults = {
            'rede': 180,
            'solar': 120,
            'gerador': 180,
            'ups': 10
        };
        return defaults[fonte] || 100;
    }
    
    applyConfiguration(config) {
        // Apply update interval if changed
        if (this.updateInterval && config.intervalo_leitura !== this.currentUpdateInterval) {
            clearInterval(this.updateInterval);
            this.currentUpdateInterval = config.intervalo_leitura * 1000; // convert to ms
            this.updateInterval = setInterval(() => {
                if (this.currentSection === 'eventos') {
                    this.loadEventData();
                }
            }, this.currentUpdateInterval);
        }
        
        // Apply other configurations as needed
        this.currentLimiarTensao = config.limiar_tensao_global;
    }

    async saveConfiguration() {
        try {
            const intervalInput = document.getElementById('intervalo-leitura');
            const percentualInput = document.getElementById('percentual-instabilidade');
            const notifyFailures = document.getElementById('notify-failures');
            const notifyRecovery = document.getElementById('notify-recovery');

            // Collect thresholds per source
            const thresholds = {
                rede: parseFloat(document.getElementById('threshold-rede').value),
                solar: parseFloat(document.getElementById('threshold-solar').value),
                gerador: parseFloat(document.getElementById('threshold-gerador').value),
                ups: parseFloat(document.getElementById('threshold-ups').value)
            };

            const configData = {
                intervalo_leitura: parseFloat(intervalInput.value),
                percentual_instabilidade: parseInt(percentualInput.value),
                thresholds: thresholds,
                notify_failures: notifyFailures.checked,
                notify_recovery: notifyRecovery.checked
            };

            const response = await fetch(`${this.apiUrl}/configuracao`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(configData)
            });

            const result = await response.json();
            
            if (response.ok) {
                this.showNotification('Configuration saved successfully!', 'success');
                
                // Apply new configurations immediately
                this.currentConfig = configData;
                this.applyConfiguration(configData);
                
                // Visual feedback on button
                const saveButton = document.querySelector('.config-form .btn-primary');
                if (saveButton) {
                    saveButton.textContent = 'Saved!';
                    saveButton.classList.add('btn-success');
                    setTimeout(() => {
                        saveButton.textContent = 'Save';
                        saveButton.classList.remove('btn-success');
                    }, 2000);
                }
            } else {
                // Handle validation errors from backend
                if (result.erros && result.erros.length > 0) {
                    const errorMessages = result.erros.join('<br>');
                    this.showNotification(`Validation error:<br>${errorMessages}`, 'error');
                } else {
                    this.showNotification(result.message || 'Error saving configuration', 'error');
                }
            }
        } catch (error) {
            this.showNotification('Error saving configuration', 'error');
        }
    }

    async exportEvents() {
        try {
            const filtroFonte = document.getElementById('filtro-fonte')?.value || '';
            const filtroTipo = document.getElementById('filtro-tipo')?.value || '';
            
            let url = `${this.apiUrl}/exportar?formato=csv`;
            
            if (filtroFonte) {
                url += `&fontes=${filtroFonte}`;
            }
            
            // Add period filter (last 30 days by default)
            const dataInicio = new Date();
            dataInicio.setDate(dataInicio.getDate() - 30);
            url += `&data_inicio=${dataInicio.toISOString().split('T')[0]}`;
            
            // Criar link de download
            const link = document.createElement('a');
            link.href = url;
            link.download = `poweredge_eventos_${new Date().toISOString().split('T')[0]}.csv`;
            link.click();
            
            this.showNotification('Export started! File downloaded.', 'success');
        } catch (error) {
            this.showNotification('Error exporting events', 'error');
        }
    }

    updateQuickStatus(data) {
        const container = document.getElementById('quick-status-container');
        if (!container || !data) return;
        
        container.innerHTML = '';
        
        // Sort sources by priority
        const sortedSources = Object.keys(data).sort((a, b) => {
            const priorityA = this.sourceConfig[a]?.priority || 999;
            const priorityB = this.sourceConfig[b]?.priority || 999;
            return priorityA - priorityB;
        });
        
        sortedSources.forEach(sourceName => {
            const sourceData = data[sourceName];
            const config = this.sourceConfig[sourceName];
            
            const item = document.createElement('div');
            item.className = `quick-status-item status-${sourceData.estado.toLowerCase()}`;
            item.innerHTML = `
                <div class="status-icon">${config?.icon || '⚡'}</div>
                <div class="status-info">
                    <div class="status-name">${config?.name || sourceName}</div>
                    <div class="status-details">${sourceData.tensao}V - ${this.translateStatus(sourceData.estado)}</div>
                </div>
                <div class="status-indicator ${sourceData.estado.toLowerCase()}"></div>
            `;
            
            container.appendChild(item);
        });
    }

    // Notification System
    showNotification(message, type = 'info', duration = 5000, isAlarm = false) {
        // Use different container for alarms
        const containerClass = isAlarm ? 'alarm-notification-container' : 'notification-container';
        const notificationClass = isAlarm ? 'alarm-notification' : 'notification';
        
        // Create notification container if it doesn't exist
        let container = document.getElementById(containerClass);
        if (!container) {
            container = document.createElement('div');
            container.id = containerClass;
            container.className = containerClass;
            document.body.appendChild(container);
        }

        // Create notification element
        const notification = document.createElement('div');
        notification.className = `${notificationClass} notification-${type}`;
        
        // Add appropriate icon
        const icons = {
            'success': '✅',
            'error': '❌',
            'warning': '⚠️',
            'info': 'ℹ️'
        };
        
        notification.innerHTML = `
            <div class="notification-content">
                <span class="notification-icon">${icons[type] || icons.info}</span>
                <span class="notification-message">${message}</span>
                <button class="notification-close" onclick="this.parentElement.parentElement.remove()">&times;</button>
            </div>
        `;

        // Add to container
        container.appendChild(notification);

        // Auto-remove after duration
        setTimeout(() => {
            if (notification.parentElement) {
                const fadeClass = isAlarm ? 'alarm-notification-fade-out' : 'notification-fade-out';
                notification.classList.add(fadeClass);
                setTimeout(() => {
                    if (notification.parentElement) {
                        notification.remove();
                    }
                }, 300);
            }
        }, duration);

        // Remove on click
        notification.addEventListener('click', () => {
            notification.remove();
        });
    }

    // Advanced notification with actions
    showAdvancedNotification(message, type = 'info', actions = [], duration = 8000, isAlarm = false) {
        const containerClass = isAlarm ? 'alarm-notification-container' : 'notification-container';
        const notificationClass = isAlarm ? 'alarm-notification' : 'notification';
        
        let container = document.getElementById(containerClass);
        if (!container) {
            container = document.createElement('div');
            container.id = containerClass;
            container.className = containerClass;
            document.body.appendChild(container);
        }

        const notification = document.createElement('div');
        notification.className = `${notificationClass} notification-${type} notification-advanced`;
        
        const icons = {
            'success': '✅',
            'error': '❌',
            'warning': '⚠️',
            'info': 'ℹ️'
        };
        
        let actionsHtml = '';
        if (actions.length > 0) {
            actionsHtml = '<div class="notification-actions">';
            actions.forEach(action => {
                actionsHtml += `<button class="notification-action" onclick="${action.callback}">${action.text}</button>`;
            });
            actionsHtml += '</div>';
        }
        
        notification.innerHTML = `
            <div class="notification-content">
                <span class="notification-icon">${icons[type] || icons.info}</span>
                <div class="notification-text">
                    <span class="notification-message">${message}</span>
                    ${actionsHtml}
                </div>
                <button class="notification-close" onclick="this.parentElement.parentElement.remove()">&times;</button>
            </div>
        `;

        container.appendChild(notification);

        if (duration > 0) {
            setTimeout(() => {
                if (notification.parentElement) {
                    const fadeClass = isAlarm ? 'alarm-notification-fade-out' : 'notification-fade-out';
                    notification.classList.add(fadeClass);
                    setTimeout(() => {
                        if (notification.parentElement) {
                            notification.remove();
                        }
                    }, 300);
                }
            }, duration);
        }
    }

    // Smart notification for source status changes
    notifySourceStatusChange(source, oldStatus, newStatus, voltage) {
        const config = this.sourceConfig[source];
        const sourceName = config?.name || source;
        const icon = config?.icon || '⚡';
        
        let type = 'info';
        let message = '';
        let actions = [];
        let isAlarm = true; // All status changes are alarms
        
        if (newStatus === 'FALHA' && oldStatus !== 'FALHA') {
            type = 'error';
            message = `${icon} ${sourceName} failed (${voltage?.toFixed(1)}V)`;
            actions = [
                { text: 'View Events', callback: `app.showSection('eventos')` },
                { text: 'Details', callback: `app.showSourceDetails('${source}')` }
            ];
        } else if (newStatus === 'ATIVA' && oldStatus === 'FALHA') {
            type = 'success';
            message = `${icon} ${sourceName} has been restored (${voltage?.toFixed(1)}V)`;
        } else if (newStatus === 'INSTAVEL') {
            type = 'warning';
            message = `${icon} ${sourceName} is unstable (${voltage?.toFixed(1)}V)`;
        }
        
        if (message) {
            if (actions.length > 0) {
                this.showAdvancedNotification(message, type, actions, 15000, isAlarm); // 15 seconds for critical alarms
            } else {
                this.showNotification(message, type, 8000, isAlarm); // 8 seconds for simple alarms
            }
        }
    }

    // System status notification
    notifySystemStatus(status) {
        this.showNotification('🔧 Hardware mode active - Real monitoring', 'info');
    }

    // Show source details modal or section
    showSourceDetails(source) {
        const sourceData = this.sourceData[source];
        const config = this.sourceConfig[source];
        
        if (!sourceData || !config) return;
        
        const message = `
            <strong>${config.icon} ${config.name}</strong><br>
            <strong>Status:</strong> ${this.translateStatus(sourceData.estado)}<br>
            <strong>Voltage:</strong> ${sourceData.tensao}V<br>
            <strong>Priority:</strong> ${config.priority}<br>
            <strong>Last update:</strong> ${new Date().toLocaleTimeString()}
        `;
        
        this.showAdvancedNotification(
            message, 
            sourceData.estado === 'FALHA' ? 'error' : 
            sourceData.estado === 'INSTAVEL' ? 'warning' : 'info',
            [
                { text: 'View History', callback: `app.showSection('eventos')` },
                { text: 'Settings', callback: `app.showSection('configuracoes')` }
            ],
            0 // Don't auto-close
        );
    }

    // Enhanced system monitoring
    monitorSystemHealth() {
        // Check connection health
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            const now = Date.now();
            if (this.lastDataReceived && (now - this.lastDataReceived) > 30000) {
                this.showNotification('⚠️ No data received for more than 30 seconds', 'warning', 10000, true); // Warning alarm
            }
        }
        
        // Check for critical failures
        if (this.sourceData && Object.keys(this.sourceData).length > 0) {
            const failedSources = Object.keys(this.sourceData).filter(
                source => this.sourceData[source].estado === 'FALHA'
            );
            
            if (failedSources.length >= 3) {
                this.showAdvancedNotification(
                    `🚨 Multiple sources failed: ${failedSources.map(s => this.sourceConfig[s]?.name || s).join(', ')}`,
                    'error',
                    [
                        { text: 'View Dashboard', callback: `app.showSection('dashboard')` },
                        { text: 'Events', callback: `app.showSection('eventos')` }
                    ],
                    0, // Don't auto-close
                    true // It's a critical alarm
                );
            }
        }
    }

    updateSourceCards(data) {
        const container = document.getElementById('fontes-container');
        if (!container) return;
        container.innerHTML = '';
        if (!data || Object.keys(data).length === 0) {
            container.innerHTML = `<div class="empty-state">No power sources found or error loading power sources.</div>`;
            return;
        }
        Object.keys(data).forEach(source => {
            const fonte = data[source];
            const config = this.sourceConfig[source] || {};
            const card = document.createElement('div');
            card.className = `fonte-card fonte-${fonte.estado.toLowerCase()}`;
            card.innerHTML = `
                <div class="fonte-icon">${config.icon || '⚡'}</div>
                <div class="fonte-info">
                    <div class="fonte-nome">${config.name || source}</div>
                    <div class="fonte-tensao">${fonte.tensao}V</div>
                    <div class="fonte-estado">${this.translateStatus(fonte.estado)}</div>
                </div>
            `;
            container.appendChild(card);
        });
    }

    // Helper function to count source states consistently
    countSourceStates(sourceData = null) {
        const data = sourceData || this.sourceData || {};
        const statusCounts = {
            'ATIVA': 0,
            'FALHA': 0,
            'INSTAVEL': 0,
            'ERRO': 0,
            'DESCONHECIDO': 0
        };
        
        Object.values(data).forEach(fonte => {
            if (fonte && fonte.estado) {
                if (statusCounts.hasOwnProperty(fonte.estado)) {
                    statusCounts[fonte.estado]++;
                } else {
                    // Unrecognized states are counted as UNKNOWN
                    statusCounts['DESCONHECIDO']++;
                }
            } else {
                // Sources without defined state are counted as UNKNOWN
                statusCounts['DESCONHECIDO']++;
            }
        });
        
        // Calculate derived totals
        const totalFontes = Object.keys(data).length;
        const fontesAtivas = statusCounts['ATIVA'];
        const fontesComProblemas = statusCounts['FALHA'] + statusCounts['INSTAVEL'] + statusCounts['ERRO'];
        
        return {
            ...statusCounts,
            totalFontes,
            fontesAtivas,
            fontesComProblemas,
            fontesDesconhecidas: statusCounts['DESCONHECIDO']
        };
    }

    // Function to validate source counting consistency
    validateSourceCounting() {
        const sourceStates = this.countSourceStates();
        const totalCalculado = sourceStates.fontesAtivas + sourceStates.fontesComProblemas + sourceStates.fontesDesconhecidas;
        
        if (totalCalculado !== sourceStates.totalFontes) {           
            // Show alert notification
            this.showNotification(
                `⚠️ Counting inconsistency: ${sourceStates.totalFontes} sources vs ${totalCalculado} accounted`,
                'warning',
                8000
            );
        } else {
        }
        
        return totalCalculado === sourceStates.totalFontes;
    }

    // Helper function to translate status values to English
    translateStatus(status) {
        const statusTranslations = {
            'ATIVA': 'ACTIVE',
            'FALHA': 'FAILED', 
            'INSTAVEL': 'UNSTABLE',
            'ERRO': 'ERROR',
            'DESCONHECIDO': 'UNKNOWN'
        };
        return statusTranslations[status] || status;
    }
}

// Global functions for compatibility
let app;

function showSection(sectionName) {
    if (app) app.showSection(sectionName);
}

function toggleSidebar() {
    if (app) app.toggleSidebar();
}

function carregarEventos() {
    if (app) app.loadEventData();
}

function exportarEventos() {
    if (app) app.exportEvents();
}

function toggleView() {
    if (app) app.loadStatusData();
}

function loadStatistics() {
    if (app) app.loadStatistics();
}

// Initialize the application
document.addEventListener('DOMContentLoaded', () => {
    app = new PowerEdgeApp();
    window.powerEdgeApp = app; // For debugging
});

// Add additional CSS for new components
const additionalStyles = `
    <style>
    .quick-status-item {
        display: flex;
        align-items: center;
        gap: var(--space-3);
        padding: var(--space-3);
        border-radius: var(--radius-lg);
        background: var(--gray-50);
        margin-bottom: var(--space-2);
    }
    
    .status-icon {
        font-size: var(--font-size-xl);
        width: 40px;
        text-align: center;
    }
    
    .status-info {
        flex: 1;
    }
    
    .status-name {
        font-weight: 600;
        color: var(--gray-900);
    }
    
    .status-details {
        font-size: var(--font-size-sm);
        color: var(--gray-600);
    }
    
    .status-indicator.ativa {
        width: 12px;
        height: 12px;
        border-radius: 50%;
        background: var(--success-500);
    }
    
    .status-indicator.falha {
        width: 12px;
        height: 12px;
        border-radius: 50%;
        background: var(--danger-500);
    }
    
    .status-indicator.erro {
        width: 12px;
        height: 12px;
        border-radius: 50%;
        background: var(--warning-500);
    }
    
    .recent-event-item {
        display: flex;
        align-items: center;
        gap: var(--space-3);
        padding: var(--space-3);
        border-bottom: 1px solid var(--gray-100);
    }
    
    .recent-event-item:last-child {
        border-bottom: none;
    }
    
    .event-icon {
        font-size: var(--font-size-lg);
    }
    
    .event-content {
        flex: 1;
    }
    
    .event-title {
        font-weight: 500;
        color: var(--gray-900);
        font-size: var(--font-size-sm);
    }
    
    .event-time {
        font-size: var(--font-size-xs);
        color: var(--gray-500);
    }
    
    .empty-state {
        text-align: center;
        padding: var(--space-8);
        color: var(--gray-500);
    }
    
    .notification-content {
        display: flex;
        justify-content: space-between;
        align-items: center;
    }
    
    .notification-close {
        background: none;
        border: none;
        font-size: var(--font-size-lg);
        cursor: pointer;
        color: var(--gray-500);
        padding: 0;
        margin-left: var(--space-3);
    }
    </style>
`;

document.head.insertAdjacentHTML('beforeend', additionalStyles);
