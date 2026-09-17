(() => {
    const $ = (selector) => document.querySelector(selector);
    const $$ = (selector) => [...document.querySelectorAll(selector)];

    const state = {
        mode: 'login',
        busy: false,
        sex: 'male',
        audioEnabled: true,
        audioContext: null,
        musicTimer: null,
        configured: false,
        loadingComplete: false,
        minimumAge: 18,
        maximumAge: 80,
        responseTimer: null
    };

    const loadingView = $('#loadingView');
    const authView = $('#authView');
    const form = $('#authForm');
    const username = $('#username');
    const password = $('#password');
    const confirmPassword = $('#confirmPassword');
    const characterName = $('#characterName');
    const characterAge = $('#characterAge');
    const registerFields = $('#registerFields');
    const feedback = $('#feedback');
    const submitButton = $('#submitButton');
    const submitText = $('#submitText');
    const progressBar = $('#progressBar');
    const loadingPercent = $('#loadingPercent');
    const loadingStatus = $('#loadingStatus');
    const progressType = $('#progressType');
    const successOverlay = $('#successOverlay');

    function hexToRgb(hex) {
        const clean = String(hex).replace('#', '');
        const value = parseInt(clean.length === 3 ? clean.split('').map((x) => x + x).join('') : clean, 16);
        return `${(value >> 16) & 255}, ${(value >> 8) & 255}, ${value & 255}`;
    }

    function configure(config) {
        if (state.configured) return;
        state.configured = true;
        state.minimumAge = Number(config.minimumAge) || 18;
        state.maximumAge = Number(config.maximumAge) || 80;

        $$('[data-brand]').forEach((node) => { node.textContent = config.brand || 'NexusRP'; });
        $$('[data-subtitle]').forEach((node) => { node.textContent = config.subtitle || ''; });

        const accent = config.accent || '#8B5CF6';
        document.documentElement.style.setProperty('--accent', accent);
        document.documentElement.style.setProperty('--accent-rgb', hexToRgb(accent));
        characterAge.min = state.minimumAge;
        characterAge.max = state.maximumAge;
        characterAge.placeholder = String(state.minimumAge);
        startMusic();
    }

    function updateProgress(data) {
        if (state.loadingComplete) return;
        const percentage = Math.max(0, Math.min(100, Math.floor(Number(data.percentage) || 0)));
        progressBar.style.width = `${percentage}%`;
        loadingPercent.textContent = `${percentage}%`;
        loadingStatus.textContent = data.status || 'Carregando dados do servidor...';
        progressType.textContent = data.real ? 'DOWNLOAD REAL DO SERVIDOR' : 'INICIALIZANDO SISTEMAS';
    }

    function completeLoading() {
        if (state.loadingComplete) return;
        state.loadingComplete = true;
        progressBar.style.width = '100%';
        loadingPercent.textContent = '100%';
        loadingStatus.textContent = 'Todos os dados foram carregados.';
        progressType.textContent = 'SERVIDOR PRONTO';
        setTimeout(showAuth, 700);
    }

    function showAuth() {
        loadingView.classList.remove('active');
        authView.classList.add('active');
        setTimeout(() => username.focus(), 700);
    }

    function setMode(mode, successMessage, savedUsername) {
        if (state.busy) return;
        state.mode = mode;
        feedback.textContent = successMessage || '';
        feedback.className = `feedback${successMessage ? ' success' : ''}`;
        form.reset();

        if (savedUsername) username.value = savedUsername;
        $$('.tab').forEach((tab) => tab.classList.toggle('active', tab.dataset.mode === mode));

        const register = mode === 'register';
        [confirmPassword, characterName, characterAge].forEach((input) => { input.disabled = !register; });
        registerFields.classList.toggle('hidden', !register);
        confirmPassword.required = register;
        characterName.required = register;
        characterAge.required = register;
        $('#authCard').classList.toggle('register-mode', register);
        $('#formEyebrow').textContent = register ? 'PRIMEIRO ACESSO' : 'BEM-VINDO DE VOLTA';
        $('#formTitle').textContent = register ? 'Crie sua identidade' : 'Acesse sua conta';
        submitText.textContent = register ? 'FINALIZAR CADASTRO' : 'ENTRAR NA CIDADE';
        $('#switchText').innerHTML = register
            ? 'Já possui uma conta? <button type="button" data-switch>Entre agora</button>'
            : 'Ainda não possui uma conta? <button type="button" data-switch>Crie seu personagem</button>';
        $('#switchText').querySelector('[data-switch]').addEventListener('click', () => setMode(register ? 'login' : 'register'));
        selectSex('male');
        setTimeout(() => username.focus(), 20);
    }

    function selectSex(sex) {
        state.sex = sex;
        $$('.character-card').forEach((card) => card.classList.toggle('selected', card.dataset.sex === sex));
    }

    function setBusy(busy) {
        state.busy = busy;
        submitButton.disabled = busy;
        submitText.textContent = busy
            ? 'PROCESSANDO...'
            : state.mode === 'register' ? 'FINALIZAR CADASTRO' : 'ENTRAR NA CIDADE';
    }

    function receive(result) {
        clearTimeout(state.responseTimer);
        state.responseTimer = null;
        setBusy(false);

        if (result.ok && result.registered) {
            setMode('login', result.message, result.username);
            return;
        }

        feedback.textContent = result.message || '';
        feedback.className = `feedback${result.ok ? ' success' : ''}`;

        if (result.ok) {
            successOverlay.classList.add('active');
            fadeMusic();
        }
    }

    function submit(event) {
        event.preventDefault();
        if (state.busy) return;
        feedback.textContent = '';
        feedback.className = 'feedback';

        if (state.mode === 'register' && password.value !== confirmPassword.value) {
            feedback.textContent = 'As senhas não são iguais.';
            return;
        }

        const age = Number(characterAge.value);
        if (state.mode === 'register' && (age < state.minimumAge || age > state.maximumAge)) {
            feedback.textContent = `A idade deve estar entre ${state.minimumAge} e ${state.maximumAge} anos.`;
            return;
        }

        setBusy(true);

        try {
            if (typeof mta === 'undefined' || typeof mta.triggerEvent !== 'function') {
                throw new Error('Ponte do MTA indisponível');
            }

            mta.triggerEvent(
                'nexusAuth:submitFromBrowser',
                String(state.mode),
                String(username.value.trim()),
                String(password.value),
                String(state.mode === 'register' ? characterName.value.trim() : ''),
                String(state.mode === 'register' ? characterAge.value : ''),
                String(state.mode === 'register' ? state.sex : '')
            );

            clearTimeout(state.responseTimer);
            state.responseTimer = setTimeout(() => {
                setBusy(false);
                feedback.textContent = 'O servidor não respondeu. Verifique o console para identificar o erro.';
                feedback.className = 'feedback';
            }, 8000);
        } catch (error) {
            setBusy(false);
            feedback.textContent = `Falha ao comunicar com o MTA: ${error.message}`;
            feedback.className = 'feedback';
        }
    }

    function createVoice(ctx, destination, frequency, start, duration, gainValue) {
        const oscillator = ctx.createOscillator();
        const gain = ctx.createGain();
        oscillator.type = 'sine';
        oscillator.frequency.value = frequency;
        gain.gain.setValueAtTime(0, start);
        gain.gain.linearRampToValueAtTime(gainValue, start + Math.min(1.2, duration / 3));
        gain.gain.setValueAtTime(gainValue, start + duration - Math.min(1.2, duration / 3));
        gain.gain.linearRampToValueAtTime(0, start + duration);
        oscillator.connect(gain).connect(destination);
        oscillator.start(start);
        oscillator.stop(start + duration + .1);
    }

    function scheduleMusic() {
        const ctx = state.audioContext;
        if (!ctx || !state.audioEnabled) return;
        const master = ctx.createGain();
        const filter = ctx.createBiquadFilter();
        master.gain.value = .11;
        filter.type = 'lowpass';
        filter.frequency.value = 980;
        master.connect(filter).connect(ctx.destination);
        const chords = [[110,130.81,164.81],[98,123.47,146.83],[82.41,110,130.81],[92.5,116.54,146.83]];
        const start = ctx.currentTime + .08;
        chords.forEach((chord, index) => {
            chord.forEach((note, voice) => createVoice(ctx, master, note, start + (index * 4), 4.15, voice === 0 ? .55 : .32));
            createVoice(ctx, master, chord[0] * 2, start + (index * 4) + 1.75, 1.8, .08);
        });
        clearTimeout(state.musicTimer);
        state.musicTimer = setTimeout(scheduleMusic, 15800);
    }

    function startMusic() {
        if (!state.audioEnabled) return;
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        if (!AudioContext) return;
        if (!state.audioContext) {
            state.audioContext = new AudioContext();
            scheduleMusic();
        } else if (state.audioContext.state === 'suspended') {
            state.audioContext.resume();
        }
        updateSoundButtons();
    }

    function toggleMusic() {
        state.audioEnabled = !state.audioEnabled;
        if (state.audioEnabled) startMusic();
        else if (state.audioContext) state.audioContext.suspend();
        updateSoundButtons();
    }

    function fadeMusic() {
        if (state.audioContext) state.audioContext.suspend();
    }

    function updateSoundButtons() {
        $('#soundIcon').textContent = state.audioEnabled ? '♫' : '×';
        $('#soundLabel').textContent = state.audioEnabled ? 'MÚSICA' : 'SEM SOM';
        $('#authSoundButton').textContent = state.audioEnabled ? '♫ MÚSICA ATIVA' : '× MÚSICA DESATIVADA';
    }

    $$('.tab').forEach((tab) => tab.addEventListener('click', () => setMode(tab.dataset.mode)));
    $('[data-switch]').addEventListener('click', () => setMode('register'));
    $$('.character-card').forEach((card) => card.addEventListener('click', () => selectSex(card.dataset.sex)));
    $('#togglePassword').addEventListener('click', () => {
        const visible = password.type === 'text';
        password.type = visible ? 'password' : 'text';
        $('#togglePassword').textContent = visible ? 'MOSTRAR' : 'OCULTAR';
    });
    $('#soundButton').addEventListener('click', toggleMusic);
    $('#authSoundButton').addEventListener('click', toggleMusic);
    document.addEventListener('click', () => {
        if (state.audioEnabled && state.audioContext && state.audioContext.state === 'suspended') state.audioContext.resume();
    }, { once: true });
    form.addEventListener('submit', submit);

    window.NexusAuth = { configure, updateProgress, completeLoading, receive };
    setMode('login');

    if (!window.mta) {
        configure({ brand: 'NexusRP', subtitle: 'UMA NOVA HISTÓRIA COMEÇA AQUI', accent: '#8B5CF6', minimumAge: 18, maximumAge: 80 });
        let demo = 0;
        const previewTimer = setInterval(() => {
            demo += 4;
            updateProgress({ percentage: demo, status: `Baixando dados e mods • ${demo} MB / 100 MB`, real: true });
            if (demo >= 100) {
                clearInterval(previewTimer);
                completeLoading();
            }
        }, 90);
    }
})();
